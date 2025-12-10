/**
 * Toast 通知组件
 * 在页面上显示导入状态反馈
 */

export type ToastType = 'success' | 'error' | 'loading';

interface ToastOptions {
  message: string;
  type: ToastType;
  duration?: number; // 毫秒，0 表示不自动关闭
}

/** Toast 容器 ID */
const TOAST_CONTAINER_ID = 'crm-toast-container';

/** Toast 样式 */
const TOAST_STYLES = `
  .crm-toast-container {
    position: fixed;
    top: 20px;
    right: 20px;
    z-index: 2147483647;
    display: flex;
    flex-direction: column;
    gap: 8px;
    pointer-events: none;
  }

  .crm-toast {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 12px 16px;
    border-radius: 8px;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'PingFang SC', 'Microsoft YaHei', sans-serif;
    font-size: 14px;
    line-height: 1.5;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    pointer-events: auto;
    animation: crm-toast-slide-in 0.3s ease;
    max-width: 360px;
  }

  .crm-toast.crm-toast-exit {
    animation: crm-toast-slide-out 0.3s ease forwards;
  }

  .crm-toast-success {
    background: #f6ffed;
    border: 1px solid #b7eb8f;
    color: #52c41a;
  }

  .crm-toast-error {
    background: #fff2f0;
    border: 1px solid #ffccc7;
    color: #ff4d4f;
  }

  .crm-toast-loading {
    background: #e6f4ff;
    border: 1px solid #91caff;
    color: #1677ff;
  }

  .crm-toast-icon {
    flex-shrink: 0;
    width: 20px;
    height: 20px;
  }

  .crm-toast-spinner {
    width: 20px;
    height: 20px;
    border: 2px solid #91caff;
    border-top-color: #1677ff;
    border-radius: 50%;
    animation: crm-toast-spin 0.8s linear infinite;
  }

  .crm-toast-message {
    flex: 1;
    word-break: break-word;
  }

  .crm-toast-close {
    flex-shrink: 0;
    width: 16px;
    height: 16px;
    cursor: pointer;
    opacity: 0.5;
    transition: opacity 0.2s;
  }

  .crm-toast-close:hover {
    opacity: 1;
  }

  @keyframes crm-toast-slide-in {
    from {
      opacity: 0;
      transform: translateX(100%);
    }
    to {
      opacity: 1;
      transform: translateX(0);
    }
  }

  @keyframes crm-toast-slide-out {
    from {
      opacity: 1;
      transform: translateX(0);
    }
    to {
      opacity: 0;
      transform: translateX(100%);
    }
  }

  @keyframes crm-toast-spin {
    to {
      transform: rotate(360deg);
    }
  }
`;

/** 图标 SVG */
const ICONS = {
  success: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
    <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/>
    <polyline points="22 4 12 14.01 9 11.01"/>
  </svg>`,
  error: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
    <circle cx="12" cy="12" r="10"/>
    <line x1="15" y1="9" x2="9" y2="15"/>
    <line x1="9" y1="9" x2="15" y2="15"/>
  </svg>`,
  close: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
    <line x1="18" y1="6" x2="6" y2="18"/>
    <line x1="6" y1="6" x2="18" y2="18"/>
  </svg>`,
};

/** Toast 管理器 */
class ToastManager {
  private container: HTMLElement | null = null;
  private shadowRoot: ShadowRoot | null = null;
  private toasts: Map<string, HTMLElement> = new Map();
  private toastId = 0;

  /** 初始化 Toast 容器 */
  private init(): void {
    if (this.container) return;

    // 创建容器
    this.container = document.createElement('div');
    this.container.id = TOAST_CONTAINER_ID;

    // 使用 Shadow DOM 隔离样式
    this.shadowRoot = this.container.attachShadow({ mode: 'closed' });

    // 注入样式
    const style = document.createElement('style');
    style.textContent = TOAST_STYLES;
    this.shadowRoot.appendChild(style);

    // 创建 Toast 容器
    const toastContainer = document.createElement('div');
    toastContainer.className = 'crm-toast-container';
    this.shadowRoot.appendChild(toastContainer);

    document.body.appendChild(this.container);
  }

  /** 显示 Toast */
  show(options: ToastOptions): string {
    this.init();

    const id = `toast-${++this.toastId}`;
    const { message, type, duration = type === 'loading' ? 0 : 3000 } = options;

    const toast = document.createElement('div');
    toast.className = `crm-toast crm-toast-${type}`;
    toast.setAttribute('data-id', id);

    // 图标
    const iconEl = document.createElement('span');
    iconEl.className = 'crm-toast-icon';
    if (type === 'loading') {
      iconEl.innerHTML = '<div class="crm-toast-spinner"></div>';
    } else {
      iconEl.innerHTML = ICONS[type];
    }
    toast.appendChild(iconEl);

    // 消息
    const messageEl = document.createElement('span');
    messageEl.className = 'crm-toast-message';
    messageEl.textContent = message;
    toast.appendChild(messageEl);

    // 关闭按钮（非 loading 状态）
    if (type !== 'loading') {
      const closeEl = document.createElement('span');
      closeEl.className = 'crm-toast-close';
      closeEl.innerHTML = ICONS.close;
      closeEl.addEventListener('click', () => this.hide(id));
      toast.appendChild(closeEl);
    }

    // 添加到容器
    const container = this.shadowRoot?.querySelector('.crm-toast-container');
    container?.appendChild(toast);
    this.toasts.set(id, toast);

    // 自动关闭
    if (duration > 0) {
      setTimeout(() => this.hide(id), duration);
    }

    return id;
  }

  /** 隐藏 Toast */
  hide(id: string): void {
    const toast = this.toasts.get(id);
    if (!toast) return;

    toast.classList.add('crm-toast-exit');
    setTimeout(() => {
      toast.remove();
      this.toasts.delete(id);
    }, 300);
  }

  /** 更新 Toast */
  update(id: string, options: Partial<ToastOptions>): void {
    const toast = this.toasts.get(id);
    if (!toast) return;

    if (options.message) {
      const messageEl = toast.querySelector('.crm-toast-message');
      if (messageEl) {
        messageEl.textContent = options.message;
      }
    }

    if (options.type) {
      toast.className = `crm-toast crm-toast-${options.type}`;
      
      const iconEl = toast.querySelector('.crm-toast-icon');
      if (iconEl) {
        if (options.type === 'loading') {
          iconEl.innerHTML = '<div class="crm-toast-spinner"></div>';
        } else {
          iconEl.innerHTML = ICONS[options.type];
        }
      }

      // 添加关闭按钮（如果从 loading 变为其他状态）
      if (options.type !== 'loading' && !toast.querySelector('.crm-toast-close')) {
        const closeEl = document.createElement('span');
        closeEl.className = 'crm-toast-close';
        closeEl.innerHTML = ICONS.close;
        closeEl.addEventListener('click', () => this.hide(id));
        toast.appendChild(closeEl);
      }

      // 自动关闭
      if (options.type !== 'loading') {
        const duration = options.duration ?? 3000;
        if (duration > 0) {
          setTimeout(() => this.hide(id), duration);
        }
      }
    }
  }

  /** 显示成功提示 */
  success(message: string, duration?: number): string {
    return this.show({ message, type: 'success', duration });
  }

  /** 显示错误提示 */
  error(message: string, duration?: number): string {
    return this.show({ message, type: 'error', duration: duration ?? 5000 });
  }

  /** 显示加载提示 */
  loading(message: string): string {
    return this.show({ message, type: 'loading', duration: 0 });
  }

  /** 销毁所有 Toast */
  destroy(): void {
    this.toasts.forEach((_, id) => this.hide(id));
    this.container?.remove();
    this.container = null;
    this.shadowRoot = null;
  }
}

// 导出单例
export const toast = new ToastManager();
