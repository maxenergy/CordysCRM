/**
 * Content Script
 * 在爱企查页面注入"导入到 CRM"按钮并提取企业信息
 */

import { extractEnterpriseData, validateExtractedData, waitForPageLoad } from './extractor';
import { toast } from './toast';
import type { EnterpriseImportRequest, EnterpriseImportResponse } from '../types/config';

/** 按钮容器 ID */
const BUTTON_CONTAINER_ID = 'crm-import-button-container';

/** 按钮样式 */
const BUTTON_STYLES = `
  .crm-import-container {
    position: fixed;
    right: 24px;
    bottom: 120px;
    z-index: 2147483646;
  }

  .crm-import-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    padding: 14px 24px;
    background: linear-gradient(135deg, #1677ff 0%, #4096ff 100%);
    color: white;
    border: none;
    border-radius: 28px;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'PingFang SC', 'Microsoft YaHei', sans-serif;
    font-size: 14px;
    font-weight: 500;
    cursor: pointer;
    box-shadow: 0 4px 16px rgba(22, 119, 255, 0.4);
    transition: all 0.3s ease;
    white-space: nowrap;
  }

  .crm-import-btn:hover {
    transform: translateY(-2px);
    box-shadow: 0 6px 20px rgba(22, 119, 255, 0.5);
  }

  .crm-import-btn:active {
    transform: translateY(0);
    box-shadow: 0 2px 8px rgba(22, 119, 255, 0.4);
  }

  .crm-import-btn:disabled {
    opacity: 0.7;
    cursor: not-allowed;
    transform: none;
  }

  .crm-import-btn-icon {
    width: 18px;
    height: 18px;
    flex-shrink: 0;
  }

  .crm-import-btn-spinner {
    width: 18px;
    height: 18px;
    border: 2px solid rgba(255, 255, 255, 0.3);
    border-top-color: white;
    border-radius: 50%;
    animation: crm-btn-spin 0.8s linear infinite;
  }

  @keyframes crm-btn-spin {
    to {
      transform: rotate(360deg);
    }
  }

  /* 折叠状态 */
  .crm-import-btn.collapsed {
    width: 56px;
    height: 56px;
    padding: 0;
    border-radius: 50%;
  }

  .crm-import-btn.collapsed .crm-import-btn-text {
    display: none;
  }

  .crm-import-btn.collapsed .crm-import-btn-icon {
    width: 24px;
    height: 24px;
  }
`;

/** 图标 SVG */
const IMPORT_ICON = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
  <polyline points="7 10 12 15 17 10"/>
  <line x1="12" y1="15" x2="12" y2="3"/>
</svg>`;

/** 按钮管理器 */
class ImportButtonManager {
  private container: HTMLElement | null = null;
  private shadowRoot: ShadowRoot | null = null;
  private button: HTMLButtonElement | null = null;
  private isLoading = false;

  /** 检测是否在企业详情页 */
  isEnterpriseDetailPage(): boolean {
    const url = window.location.href;
    return (
      url.includes('aiqicha.baidu.com/company_detail_') ||
      url.includes('aiqicha.baidu.com/company/')
    );
  }

  /** 初始化按钮 */
  async init(): Promise<void> {
    // 如果不在企业详情页，移除按钮
    if (!this.isEnterpriseDetailPage()) {
      this.destroy();
      return;
    }

    // 如果按钮已存在，不重复创建
    if (this.container) {
      return;
    }

    // 等待页面加载
    await waitForPageLoad();

    this.createButton();
    console.log('[CRM Extension] 导入按钮已注入');
  }

  /** 创建按钮 */
  private createButton(): void {
    // 创建容器
    this.container = document.createElement('div');
    this.container.id = BUTTON_CONTAINER_ID;

    // 使用 Shadow DOM 隔离样式
    this.shadowRoot = this.container.attachShadow({ mode: 'closed' });

    // 注入样式
    const style = document.createElement('style');
    style.textContent = BUTTON_STYLES;
    this.shadowRoot.appendChild(style);

    // 创建按钮容器
    const buttonContainer = document.createElement('div');
    buttonContainer.className = 'crm-import-container';

    // 创建按钮
    this.button = document.createElement('button');
    this.button.className = 'crm-import-btn';
    this.button.innerHTML = `
      <span class="crm-import-btn-icon">${IMPORT_ICON}</span>
      <span class="crm-import-btn-text">导入到 CRM</span>
    `;
    this.button.addEventListener('click', () => this.handleImport());

    buttonContainer.appendChild(this.button);
    this.shadowRoot.appendChild(buttonContainer);
    document.body.appendChild(this.container);
  }

  /** 设置加载状态 */
  private setLoading(loading: boolean): void {
    this.isLoading = loading;
    if (!this.button) return;

    if (loading) {
      this.button.disabled = true;
      this.button.innerHTML = `
        <span class="crm-import-btn-spinner"></span>
        <span class="crm-import-btn-text">导入中...</span>
      `;
    } else {
      this.button.disabled = false;
      this.button.innerHTML = `
        <span class="crm-import-btn-icon">${IMPORT_ICON}</span>
        <span class="crm-import-btn-text">导入到 CRM</span>
      `;
    }
  }

  /** 处理导入 */
  private async handleImport(): Promise<void> {
    if (this.isLoading) return;

    this.setLoading(true);
    const loadingToast = toast.loading('正在提取企业信息...');

    try {
      // 提取数据
      const data = extractEnterpriseData();
      const validation = validateExtractedData(data);

      if (!validation.valid) {
        toast.update(loadingToast, {
          type: 'error',
          message: validation.errors.join('；'),
        });
        return;
      }

      toast.update(loadingToast, {
        type: 'loading',
        message: '正在导入到 CRM...',
      });

      // 发送到 background script
      const response = await this.sendToBackground(data);

      if (response.success) {
        toast.update(loadingToast, {
          type: 'success',
          message: response.isNew
            ? `已创建新客户：${data.companyName}`
            : `已更新客户：${data.companyName}`,
        });
      } else if (response.conflicts && response.conflicts.length > 0) {
        const conflictFields = response.conflicts
          .map((c) => c.field)
          .join('、');
        toast.update(loadingToast, {
          type: 'error',
          message: `数据冲突：${conflictFields}`,
          duration: 5000,
        });
      } else {
        toast.update(loadingToast, {
          type: 'error',
          message: response.message || '导入失败',
        });
      }
    } catch (error) {
      console.error('[CRM Extension] Import error:', error);
      toast.update(loadingToast, {
        type: 'error',
        message: error instanceof Error ? error.message : '导入失败，请重试',
      });
    } finally {
      this.setLoading(false);
    }
  }

  /** 发送数据到 background script */
  private sendToBackground(
    data: EnterpriseImportRequest
  ): Promise<EnterpriseImportResponse> {
    return new Promise((resolve, reject) => {
      chrome.runtime.sendMessage(
        { type: 'IMPORT_ENTERPRISE', data },
        (response: EnterpriseImportResponse) => {
          if (chrome.runtime.lastError) {
            reject(new Error(chrome.runtime.lastError.message));
          } else {
            resolve(response);
          }
        }
      );
    });
  }

  /** 销毁按钮 */
  destroy(): void {
    this.container?.remove();
    this.container = null;
    this.shadowRoot = null;
    this.button = null;
  }
}

// 创建按钮管理器实例
const buttonManager = new ImportButtonManager();

// 初始化
function init(): void {
  buttonManager.init();
}

// 页面加载完成后初始化
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}

// 监听 URL 变化（SPA 页面）
let lastUrl = location.href;
const urlObserver = new MutationObserver(() => {
  const url = location.href;
  if (url !== lastUrl) {
    lastUrl = url;
    // 延迟执行，等待页面内容更新
    setTimeout(init, 100);
  }
});

urlObserver.observe(document, { subtree: true, childList: true });

// 监听 popstate 事件（浏览器前进/后退）
window.addEventListener('popstate', () => {
  setTimeout(init, 100);
});

console.log('[CRM Extension] Content script loaded');
