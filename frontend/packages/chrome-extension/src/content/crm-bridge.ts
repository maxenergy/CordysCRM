/**
 * CRM Bridge Content Script
 * 注入到 CRM 页面，作为页面与扩展 background 之间的消息桥梁
 * 使用 window.postMessage 方案，比 externally_connectable 更安全可靠
 */

/** 检查 origin 是否在白名单中 */
function isAllowedOrigin(origin: string): boolean {
  try {
    const { protocol, hostname, port } = new URL(origin);
    
    // localhost（任意端口，http/https 都允许）
    if (hostname === 'localhost' || hostname === '127.0.0.1') {
      return true;
    }
    
    // cordys.cn 域名（仅 https）
    if (protocol === 'https:') {
      if (hostname === 'cordys.cn' || hostname.endsWith('.cordys.cn')) {
        return true;
      }
    }
    
    return false;
  } catch {
    return false;
  }
}

/** 消息类型定义 */
interface SearchRequest {
  type: 'AIQICHA_SEARCH_REQUEST';
  requestId: string;
  keyword: string;
  page?: number;
  pageSize?: number;
}

interface SearchResponse {
  type: 'AIQICHA_SEARCH_RESPONSE';
  requestId: string;
  success: boolean;
  message?: string;
  items?: unknown[];
  total?: number;
}

// 立即注入扩展就绪标记（在 document_start 阶段）
const meta = document.createElement('meta');
meta.name = 'aiqicha-extension-ready';
meta.content = 'true';
// 等待 head 可用
if (document.head) {
  document.head.appendChild(meta);
} else {
  document.addEventListener('DOMContentLoaded', () => {
    document.head.appendChild(meta);
  });
}

// 监听来自页面的搜索请求
window.addEventListener('message', async (event: MessageEvent) => {
  // 安全检查：验证来源
  if (!isAllowedOrigin(event.origin)) {
    return;
  }
  
  const data = event.data as SearchRequest | undefined;
  
  // 只处理搜索请求
  if (data?.type !== 'AIQICHA_SEARCH_REQUEST') {
    return;
  }
  
  const { requestId, keyword, page = 1, pageSize = 20 } = data;
  
  console.log(`[CRM Bridge] Received search request: ${keyword}`);
  
  try {
    // 转发给 background script
    const response = await chrome.runtime.sendMessage({
      type: 'SEARCH_AIQICHA',
      keyword,
      page,
      pageSize,
    });
    
    // 将结果发回页面
    const result: SearchResponse = {
      type: 'AIQICHA_SEARCH_RESPONSE',
      requestId,
      success: response?.success ?? false,
      message: response?.message,
      items: response?.items,
      total: response?.total,
    };
    
    window.postMessage(result, event.origin);
  } catch (error) {
    // 发送错误响应
    const errorResult: SearchResponse = {
      type: 'AIQICHA_SEARCH_RESPONSE',
      requestId,
      success: false,
      message: error instanceof Error ? error.message : '扩展通信失败',
    };
    
    window.postMessage(errorResult, event.origin);
  }
});

// 响应扩展检测请求
window.addEventListener('message', (event: MessageEvent) => {
  if (!isAllowedOrigin(event.origin)) {
    return;
  }
  
  if (event.data?.type === 'AIQICHA_EXTENSION_PING') {
    window.postMessage({
      type: 'AIQICHA_EXTENSION_PONG',
      available: true,
    }, event.origin);
  }
});

console.log('[CRM Extension] CRM bridge content script loaded');
