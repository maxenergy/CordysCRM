/**
 * Background Service Worker
 * 处理消息监听和 API 调用
 */

import { loadConfig } from '../utils/storage';
import type { 
  EnterpriseImportRequest, 
  EnterpriseImportResponse,
  CRMConfig 
} from '../types/config';

/** 消息类型 */
interface ImportMessage {
  type: 'IMPORT_ENTERPRISE';
  data: EnterpriseImportRequest;
}

interface TestConnectionMessage {
  type: 'TEST_CONNECTION';
}

interface CookieRequestMessage {
  type: 'GET_AIQICHA_COOKIES';
}

/** 外部搜索消息（来自 CRM 前端） */
interface ExternalSearchMessage {
  type: 'SEARCH_AIQICHA';
  keyword: string;
  page?: number;
  pageSize?: number;
}

type ExtensionMessage = ImportMessage | TestConnectionMessage | CookieRequestMessage;

/** 请求超时时间（毫秒） */
const REQUEST_TIMEOUT = 10000;

/** 最大重试次数 */
const MAX_RETRIES = 3;

/**
 * 创建带超时的 fetch 请求
 */
async function fetchWithTimeout(
  url: string,
  options: RequestInit,
  timeout: number = REQUEST_TIMEOUT
): Promise<Response> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeout);

  try {
    const response = await fetch(url, {
      ...options,
      signal: controller.signal,
    });
    return response;
  } finally {
    clearTimeout(timeoutId);
  }
}

/**
 * 带重试的请求
 */
async function fetchWithRetry(
  url: string,
  options: RequestInit,
  retries: number = MAX_RETRIES
): Promise<Response> {
  let lastError: Error | null = null;

  for (let i = 0; i < retries; i++) {
    try {
      return await fetchWithTimeout(url, options);
    } catch (error) {
      lastError = error instanceof Error ? error : new Error('Unknown error');
      
      // 如果是认证错误，不重试
      if (lastError.message.includes('401')) {
        throw lastError;
      }
      
      // 等待后重试
      if (i < retries - 1) {
        await new Promise(resolve => setTimeout(resolve, Math.pow(2, i) * 1000));
      }
    }
  }

  throw lastError || new Error('Request failed after retries');
}

/**
 * 导入企业信息到 CRM
 */
async function importEnterprise(
  config: CRMConfig,
  data: EnterpriseImportRequest
): Promise<EnterpriseImportResponse> {
  const baseUrl = config.crmUrl.replace(/\/+$/, '');
  const endpoint = `${baseUrl}/api/enterprise/import`;

  try {
    const response = await fetchWithRetry(endpoint, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${config.jwtToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(data),
    });

    if (response.status === 401) {
      return {
        success: false,
        message: '认证失败，请重新配置 Token',
      };
    }

    if (response.status === 409) {
      const result = await response.json();
      return {
        success: false,
        conflicts: result.conflicts,
        message: '数据存在冲突',
      };
    }

    if (!response.ok) {
      return {
        success: false,
        message: `服务器错误 (${response.status})`,
      };
    }

    return await response.json();
  } catch (error) {
    if (error instanceof Error) {
      if (error.name === 'AbortError') {
        return {
          success: false,
          message: '请求超时，请检查网络连接',
        };
      }
      return {
        success: false,
        message: error.message,
      };
    }
    return {
      success: false,
      message: '发生未知错误',
    };
  }
}

/**
 * 处理来自 content script 的消息
 */
chrome.runtime.onMessage.addListener(
  (
    message: ExtensionMessage,
    _sender: chrome.runtime.MessageSender,
    sendResponse: (response: unknown) => void
  ) => {
    if (message.type === 'IMPORT_ENTERPRISE') {
      // 异步处理导入请求
      (async () => {
        try {
          const config = await loadConfig();
          
          if (!config) {
            sendResponse({
              success: false,
              message: '请先配置 CRM 连接信息',
            });
            return;
          }

          const result = await importEnterprise(config, message.data);
          sendResponse(result);
        } catch (error) {
          sendResponse({
            success: false,
            message: error instanceof Error ? error.message : '导入失败',
          });
        }
      })();

      // 返回 true 表示异步响应
      return true;
    }

    if (message.type === 'TEST_CONNECTION') {
      // 异步处理连接测试
      (async () => {
        try {
          const config = await loadConfig();
          
          if (!config) {
            sendResponse({
              success: false,
              message: '请先配置 CRM 连接信息',
            });
            return;
          }

          const baseUrl = config.crmUrl.replace(/\/+$/, '');
          const response = await fetchWithTimeout(`${baseUrl}/api/user/current`, {
            method: 'GET',
            headers: {
              'Authorization': `Bearer ${config.jwtToken}`,
            },
          });

          sendResponse({
            success: response.ok,
            message: response.ok ? '连接成功' : '连接失败',
          });
        } catch (error) {
          sendResponse({
            success: false,
            message: error instanceof Error ? error.message : '连接测试失败',
          });
        }
      })();

      return true;
    }

    if (message.type === 'GET_AIQICHA_COOKIES') {
      // 异步获取爱企查 Cookie
      (async () => {
        try {
          const cookies = await chrome.cookies.getAll({ url: 'https://aiqicha.baidu.com/' });
          const cookieString = cookies.map((c) => `${c.name}=${c.value}`).join('; ');

          if (!cookieString) {
            sendResponse({
              success: false,
              message: '未获取到 Cookie，请确认已登录爱企查',
            });
            return;
          }

          sendResponse({
            success: true,
            cookies: cookieString,
          });
        } catch (error) {
          sendResponse({
            success: false,
            message: error instanceof Error ? error.message : '获取 Cookie 失败',
          });
        }
      })();

      return true;
    }

    return false;
  }
);

/**
 * 处理来自外部网页（CRM 前端）的消息
 * 使用 externally_connectable 机制
 */
chrome.runtime.onMessageExternal.addListener(
  (
    message: ExternalSearchMessage,
    _sender: chrome.runtime.MessageSender,
    sendResponse: (response: unknown) => void
  ) => {
    // 只处理搜索请求
    if (message?.type !== 'SEARCH_AIQICHA') {
      return false;
    }

    (async () => {
      try {
        const keyword = (message.keyword || '').trim();
        const page = Number(message.page ?? 1);
        const pageSize = Number(message.pageSize ?? 20);

        if (!keyword) {
          sendResponse({
            success: false,
            message: '请输入搜索关键词',
            items: [],
            total: 0,
          });
          return;
        }

        console.log(`[CRM Extension] 搜索爱企查: ${keyword}, page=${page}, pageSize=${pageSize}`);

        const url = `https://aiqicha.baidu.com/s/advanceFilterAjax?q=${encodeURIComponent(keyword)}&p=${page}&s=${pageSize}`;
        
        const response = await fetchWithTimeout(
          url,
          {
            method: 'GET',
            credentials: 'include',
            headers: {
              'Accept': 'application/json, text/plain, */*',
              'Referer': `https://aiqicha.baidu.com/s?q=${encodeURIComponent(keyword)}`,
            },
          },
          REQUEST_TIMEOUT
        );

        // 检查是否被重定向到验证码页面
        if (response.redirected || response.url.includes('captcha') || response.url.includes('wappass')) {
          sendResponse({
            success: false,
            message: '爱企查需要验证码验证，请先在爱企查网站完成验证',
            items: [],
            total: 0,
          });
          return;
        }

        if (!response.ok) {
          sendResponse({
            success: false,
            message: `搜索请求失败 (${response.status})`,
            items: [],
            total: 0,
          });
          return;
        }

        // 检查响应类型
        const contentType = response.headers.get('content-type') || '';
        if (!contentType.includes('application/json')) {
          const text = await response.text();
          if (text.includes('captcha') || text.includes('wappass') || text.startsWith('<')) {
            sendResponse({
              success: false,
              message: '爱企查需要验证码验证，请先在爱企查网站完成验证',
              items: [],
              total: 0,
            });
            return;
          }
          sendResponse({
            success: false,
            message: '爱企查返回了无效的响应格式',
            items: [],
            total: 0,
          });
          return;
        }

        const json = await response.json();
        
        if (json?.status !== 0) {
          sendResponse({
            success: false,
            message: json?.msg || '搜索失败',
            items: [],
            total: 0,
          });
          return;
        }

        // 解析搜索结果
        const data = json?.data || {};
        const resultList = Array.isArray(data?.resultList) ? data.resultList : [];
        
        const items = resultList.map((item: Record<string, unknown>) => ({
          pid: String(item?.pid || ''),
          name: String(item?.titleName || item?.entName || ''),
          creditCode: item?.unifiedCode as string | undefined,
          legalPerson: item?.legalPerson as string | undefined,
          address: item?.regAddr as string | undefined,
          status: item?.openStatus as string | undefined,
          establishDate: item?.startDate as string | undefined,
          registeredCapital: item?.regCapital as string | undefined,
          industry: item?.industry as string | undefined,
        }));

        console.log(`[CRM Extension] 搜索成功，返回 ${items.length} 条结果`);

        sendResponse({
          success: true,
          items,
          total: Number(data?.total || 0),
        });
      } catch (error) {
        console.error('[CRM Extension] 搜索失败:', error);
        sendResponse({
          success: false,
          message: error instanceof Error ? error.message : '搜索失败',
          items: [],
          total: 0,
        });
      }
    })();

    // 返回 true 表示异步响应
    return true;
  }
);

// Service Worker 激活日志
console.log('CRM Extension background service worker activated');
