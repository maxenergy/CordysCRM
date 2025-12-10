/**
 * API 请求工具函数
 */

import type { ConnectionTestResult, CRMConfig } from '../types/config';

/** 请求超时时间（毫秒） */
const REQUEST_TIMEOUT = 10000;

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
 * 测试 CRM 连接
 * @param config CRM 配置
 * @returns 连接测试结果
 */
export async function testConnection(config: CRMConfig): Promise<ConnectionTestResult> {
  const { crmUrl, jwtToken } = config;

  // 移除末尾斜杠
  const baseUrl = crmUrl.replace(/\/+$/, '');
  const testEndpoint = `${baseUrl}/api/user/current`;

  try {
    const response = await fetchWithTimeout(testEndpoint, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${jwtToken}`,
        'Content-Type': 'application/json',
      },
    });

    if (response.ok) {
      return {
        success: true,
        message: '连接成功！',
        statusCode: response.status,
      };
    }

    if (response.status === 401) {
      return {
        success: false,
        message: '认证失败，请检查 Token 是否正确',
        statusCode: response.status,
      };
    }

    if (response.status === 403) {
      return {
        success: false,
        message: '权限不足，请检查账号权限',
        statusCode: response.status,
      };
    }

    return {
      success: false,
      message: `服务器返回错误 (${response.status})`,
      statusCode: response.status,
    };
  } catch (error) {
    if (error instanceof Error) {
      if (error.name === 'AbortError') {
        return {
          success: false,
          message: '连接超时，请检查网络或 CRM 地址',
        };
      }
      
      if (error.message.includes('Failed to fetch')) {
        return {
          success: false,
          message: '无法连接到服务器，请检查 CRM 地址',
        };
      }

      return {
        success: false,
        message: `连接失败: ${error.message}`,
      };
    }

    return {
      success: false,
      message: '发生未知错误',
    };
  }
}
