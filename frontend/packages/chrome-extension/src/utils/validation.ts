/**
 * 表单验证工具函数
 */

/** URL 验证结果 */
export interface ValidationResult {
  valid: boolean;
  message: string;
}

/**
 * 验证 URL 格式
 * @param url 待验证的 URL
 * @returns 验证结果
 */
export function validateUrl(url: string): ValidationResult {
  if (!url || url.trim() === '') {
    return {
      valid: false,
      message: '请输入 CRM 地址',
    };
  }

  const trimmedUrl = url.trim();

  // 检查是否以 http:// 或 https:// 开头
  if (!trimmedUrl.startsWith('http://') && !trimmedUrl.startsWith('https://')) {
    return {
      valid: false,
      message: 'URL 必须以 http:// 或 https:// 开头',
    };
  }

  try {
    const parsedUrl = new URL(trimmedUrl);
    
    // 检查是否有有效的主机名
    if (!parsedUrl.hostname) {
      return {
        valid: false,
        message: '请输入有效的域名',
      };
    }

    // 检查是否为 localhost 或有效域名格式
    const hostnamePattern = /^(localhost|(\d{1,3}\.){3}\d{1,3}|[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*)$/;
    if (!hostnamePattern.test(parsedUrl.hostname)) {
      return {
        valid: false,
        message: '请输入有效的域名格式',
      };
    }

    return {
      valid: true,
      message: '',
    };
  } catch {
    return {
      valid: false,
      message: '请输入有效的 URL',
    };
  }
}

/**
 * 验证 JWT Token 格式
 * @param token 待验证的 Token
 * @returns 验证结果
 */
export function validateToken(token: string): ValidationResult {
  if (!token || token.trim() === '') {
    return {
      valid: false,
      message: '请输入 JWT Token',
    };
  }

  const trimmedToken = token.trim();

  // JWT Token 最小长度检查
  if (trimmedToken.length < 10) {
    return {
      valid: false,
      message: 'Token 长度不足',
    };
  }

  return {
    valid: true,
    message: '',
  };
}
