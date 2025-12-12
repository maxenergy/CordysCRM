/**
 * Popup 配置界面逻辑
 * 实现 CRM 连接配置的保存和测试功能
 */

import { saveConfig, loadConfig } from '../utils/storage';
import { testConnection } from '../utils/api';
import { validateUrl, validateToken } from '../utils/validation';
import type { CRMConfig } from '../types/config';

/** 从 CRM 复制的配置格式 */
interface CRMConfigClipboard {
  crmUrl: string;
  token: string;
  timestamp?: number;
}

/** DOM 元素引用 */
interface DOMElements {
  form: HTMLFormElement;
  crmUrlInput: HTMLInputElement;
  jwtTokenInput: HTMLInputElement;
  saveBtn: HTMLButtonElement;
  testBtn: HTMLButtonElement;
  toggleTokenBtn: HTMLButtonElement;
  pasteConfigBtn: HTMLButtonElement;
  statusMessage: HTMLDivElement;
  urlError: HTMLDivElement;
  tokenError: HTMLDivElement;
}

/** 获取 DOM 元素 */
function getDOMElements(): DOMElements {
  return {
    form: document.getElementById('settings-form') as HTMLFormElement,
    crmUrlInput: document.getElementById('crm-url') as HTMLInputElement,
    jwtTokenInput: document.getElementById('jwt-token') as HTMLInputElement,
    saveBtn: document.getElementById('save-btn') as HTMLButtonElement,
    testBtn: document.getElementById('test-btn') as HTMLButtonElement,
    toggleTokenBtn: document.getElementById('toggle-token') as HTMLButtonElement,
    pasteConfigBtn: document.getElementById('paste-config-btn') as HTMLButtonElement,
    statusMessage: document.getElementById('status-message') as HTMLDivElement,
    urlError: document.getElementById('url-error') as HTMLDivElement,
    tokenError: document.getElementById('token-error') as HTMLDivElement,
  };
}

/** 显示状态消息 */
function showStatus(
  element: HTMLDivElement,
  message: string,
  type: 'success' | 'error',
  duration: number = 3000
): void {
  element.textContent = message;
  element.className = `status-message ${type}`;

  if (duration > 0) {
    setTimeout(() => {
      element.className = 'status-message';
      element.textContent = '';
    }, duration);
  }
}

/** 设置按钮加载状态 */
function setButtonLoading(button: HTMLButtonElement, loading: boolean): void {
  const content = button.querySelector('.btn-content') as HTMLElement;
  const loadingEl = button.querySelector('.btn-loading') as HTMLElement;

  if (loading) {
    content.style.display = 'none';
    loadingEl.style.display = 'flex';
    button.disabled = true;
  } else {
    content.style.display = 'flex';
    loadingEl.style.display = 'none';
    button.disabled = false;
  }
}

/** 验证 URL 输入 */
function handleUrlValidation(input: HTMLInputElement, errorEl: HTMLDivElement): boolean {
  const result = validateUrl(input.value);
  
  input.classList.remove('valid', 'invalid');
  
  if (input.value.trim() === '') {
    errorEl.textContent = '';
    return false;
  }
  
  if (result.valid) {
    input.classList.add('valid');
    errorEl.textContent = '';
    return true;
  } else {
    input.classList.add('invalid');
    errorEl.textContent = result.message;
    return false;
  }
}

/** 验证 Token 输入 */
function handleTokenValidation(input: HTMLInputElement, errorEl: HTMLDivElement): boolean {
  const result = validateToken(input.value);
  
  input.classList.remove('valid', 'invalid');
  
  if (input.value.trim() === '') {
    errorEl.textContent = '';
    return false;
  }
  
  if (result.valid) {
    input.classList.add('valid');
    errorEl.textContent = '';
    return true;
  } else {
    input.classList.add('invalid');
    errorEl.textContent = result.message;
    return false;
  }
}

/** 切换密码可见性 */
function togglePasswordVisibility(
  input: HTMLInputElement,
  button: HTMLButtonElement
): void {
  const eyeIcon = button.querySelector('.icon-eye') as SVGElement;
  const eyeOffIcon = button.querySelector('.icon-eye-off') as SVGElement;

  if (input.type === 'password') {
    input.type = 'text';
    eyeIcon.style.display = 'none';
    eyeOffIcon.style.display = 'block';
  } else {
    input.type = 'password';
    eyeIcon.style.display = 'block';
    eyeOffIcon.style.display = 'none';
  }
}

/** 加载已保存的配置 */
async function loadSavedConfig(elements: DOMElements): Promise<void> {
  try {
    const config = await loadConfig();
    if (config) {
      elements.crmUrlInput.value = config.crmUrl;
      elements.jwtTokenInput.value = config.jwtToken;
      
      // 验证已加载的值
      handleUrlValidation(elements.crmUrlInput, elements.urlError);
      handleTokenValidation(elements.jwtTokenInput, elements.tokenError);
    }
  } catch (error) {
    console.error('Failed to load config:', error);
  }
}

/** 解析剪贴板中的配置 */
function parseClipboardConfig(text: string): CRMConfigClipboard | null {
  try {
    const data = JSON.parse(text);
    // 验证必要字段
    if (data.crmUrl && data.token) {
      return {
        crmUrl: data.crmUrl,
        token: data.token,
        timestamp: data.timestamp,
      };
    }
    return null;
  } catch {
    return null;
  }
}

/** 粘贴配置 */
async function handlePasteConfig(elements: DOMElements): Promise<void> {
  try {
    let text = '';
    
    // 尝试使用 Clipboard API
    if (navigator.clipboard && navigator.clipboard.readText) {
      try {
        text = await navigator.clipboard.readText();
      } catch (clipboardError) {
        console.warn('Clipboard API failed, trying fallback:', clipboardError);
        // 如果 Clipboard API 失败，提示用户手动粘贴
        showStatus(
          elements.statusMessage,
          '无法自动读取剪贴板。请手动粘贴：先点击 CRM 地址输入框，然后按 Ctrl+V',
          'error',
          8000
        );
        elements.crmUrlInput.focus();
        return;
      }
    } else {
      showStatus(
        elements.statusMessage,
        '浏览器不支持剪贴板 API，请手动粘贴配置',
        'error',
        5000
      );
      return;
    }
    
    const config = parseClipboardConfig(text);
    
    if (!config) {
      showStatus(
        elements.statusMessage,
        '剪贴板中没有有效的配置信息，请先从 CRM 系统复制配置',
        'error',
        5000
      );
      return;
    }
    
    // 填充表单
    elements.crmUrlInput.value = config.crmUrl;
    elements.jwtTokenInput.value = config.token;
    
    // 验证填充的值
    const urlValid = handleUrlValidation(elements.crmUrlInput, elements.urlError);
    const tokenValid = handleTokenValidation(elements.jwtTokenInput, elements.tokenError);
    
    if (urlValid && tokenValid) {
      showStatus(elements.statusMessage, '配置已填充，请点击「连接测试」验证', 'success', 5000);
    } else {
      showStatus(elements.statusMessage, '配置已填充，但部分内容可能无效', 'error', 5000);
    }
  } catch (error) {
    // 可能是权限问题
    showStatus(
      elements.statusMessage,
      '无法读取剪贴板，请手动粘贴配置到输入框',
      'error',
      5000
    );
    console.error('Failed to read clipboard:', error);
  }
}

/** 保存配置 */
async function handleSave(elements: DOMElements): Promise<void> {
  const urlValid = handleUrlValidation(elements.crmUrlInput, elements.urlError);
  const tokenValid = handleTokenValidation(elements.jwtTokenInput, elements.tokenError);

  if (!urlValid || !tokenValid) {
    showStatus(elements.statusMessage, '请检查输入项', 'error');
    return;
  }

  setButtonLoading(elements.saveBtn, true);

  try {
    const config: CRMConfig = {
      crmUrl: elements.crmUrlInput.value.trim(),
      jwtToken: elements.jwtTokenInput.value.trim(),
    };

    await saveConfig(config);
    showStatus(elements.statusMessage, '设置已保存！', 'success');
  } catch (error) {
    const message = error instanceof Error ? error.message : '保存失败';
    showStatus(elements.statusMessage, message, 'error');
  } finally {
    setButtonLoading(elements.saveBtn, false);
  }
}

/** 测试连接 */
async function handleTest(elements: DOMElements): Promise<void> {
  const urlValid = handleUrlValidation(elements.crmUrlInput, elements.urlError);
  const tokenValid = handleTokenValidation(elements.jwtTokenInput, elements.tokenError);

  if (!urlValid || !tokenValid) {
    showStatus(elements.statusMessage, '请先填写完整的配置信息', 'error');
    return;
  }

  setButtonLoading(elements.testBtn, true);

  try {
    const config: CRMConfig = {
      crmUrl: elements.crmUrlInput.value.trim(),
      jwtToken: elements.jwtTokenInput.value.trim(),
    };

    const result = await testConnection(config);
    
    if (result.success) {
      showStatus(elements.statusMessage, result.message, 'success');
    } else {
      showStatus(elements.statusMessage, result.message, 'error', 5000);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : '测试失败';
    showStatus(elements.statusMessage, message, 'error');
  } finally {
    setButtonLoading(elements.testBtn, false);
  }
}

/** 处理手动粘贴事件 - 自动解析 JSON 配置 */
function handleManualPaste(event: ClipboardEvent, elements: DOMElements): void {
  const text = event.clipboardData?.getData('text');
  if (!text) return;
  
  const config = parseClipboardConfig(text);
  if (config) {
    // 阻止默认粘贴行为
    event.preventDefault();
    
    // 填充表单
    elements.crmUrlInput.value = config.crmUrl;
    elements.jwtTokenInput.value = config.token;
    
    // 验证填充的值
    const urlValid = handleUrlValidation(elements.crmUrlInput, elements.urlError);
    const tokenValid = handleTokenValidation(elements.jwtTokenInput, elements.tokenError);
    
    if (urlValid && tokenValid) {
      showStatus(elements.statusMessage, '配置已自动填充，请点击「连接测试」验证', 'success', 5000);
    } else {
      showStatus(elements.statusMessage, '配置已填充，但部分内容可能无效', 'error', 5000);
    }
  }
}

/** 初始化 */
function init(): void {
  const elements = getDOMElements();

  // 加载已保存的配置
  loadSavedConfig(elements);

  // 粘贴配置按钮
  elements.pasteConfigBtn.addEventListener('click', () => {
    handlePasteConfig(elements);
  });

  // 监听手动粘贴事件 - 在任意输入框粘贴 JSON 配置时自动解析
  elements.crmUrlInput.addEventListener('paste', (e) => {
    handleManualPaste(e, elements);
  });
  elements.jwtTokenInput.addEventListener('paste', (e) => {
    handleManualPaste(e, elements);
  });

  // URL 输入验证
  elements.crmUrlInput.addEventListener('input', () => {
    handleUrlValidation(elements.crmUrlInput, elements.urlError);
  });

  elements.crmUrlInput.addEventListener('blur', () => {
    handleUrlValidation(elements.crmUrlInput, elements.urlError);
  });

  // Token 输入验证
  elements.jwtTokenInput.addEventListener('input', () => {
    handleTokenValidation(elements.jwtTokenInput, elements.tokenError);
  });

  elements.jwtTokenInput.addEventListener('blur', () => {
    handleTokenValidation(elements.jwtTokenInput, elements.tokenError);
  });

  // 切换密码可见性
  elements.toggleTokenBtn.addEventListener('click', () => {
    togglePasswordVisibility(elements.jwtTokenInput, elements.toggleTokenBtn);
  });

  // 保存按钮
  elements.saveBtn.addEventListener('click', () => {
    handleSave(elements);
  });

  // 测试按钮
  elements.testBtn.addEventListener('click', () => {
    handleTest(elements);
  });

  // 表单提交（回车键）
  elements.form.addEventListener('submit', (e) => {
    e.preventDefault();
    handleSave(elements);
  });
}

// 页面加载完成后初始化
document.addEventListener('DOMContentLoaded', init);
