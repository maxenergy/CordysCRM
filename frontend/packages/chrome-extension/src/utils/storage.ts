/**
 * Chrome Storage 工具函数
 */

import type { CRMConfig } from '../types/config';
import { CONFIG_KEYS } from '../types/config';

/**
 * 保存 CRM 配置到 chrome.storage.local
 */
export async function saveConfig(config: CRMConfig): Promise<void> {
  return new Promise((resolve, reject) => {
    chrome.storage.local.set(
      {
        [CONFIG_KEYS.CRM_URL]: config.crmUrl,
        [CONFIG_KEYS.JWT_TOKEN]: config.jwtToken,
      },
      () => {
        if (chrome.runtime.lastError) {
          reject(new Error(chrome.runtime.lastError.message));
        } else {
          resolve();
        }
      }
    );
  });
}

/**
 * 从 chrome.storage.local 读取 CRM 配置
 */
export async function loadConfig(): Promise<CRMConfig | null> {
  return new Promise((resolve, reject) => {
    chrome.storage.local.get(
      [CONFIG_KEYS.CRM_URL, CONFIG_KEYS.JWT_TOKEN],
      (result) => {
        if (chrome.runtime.lastError) {
          reject(new Error(chrome.runtime.lastError.message));
        } else if (result[CONFIG_KEYS.CRM_URL] && result[CONFIG_KEYS.JWT_TOKEN]) {
          resolve({
            crmUrl: result[CONFIG_KEYS.CRM_URL],
            jwtToken: result[CONFIG_KEYS.JWT_TOKEN],
          });
        } else {
          resolve(null);
        }
      }
    );
  });
}

/**
 * 清除 CRM 配置
 */
export async function clearConfig(): Promise<void> {
  return new Promise((resolve, reject) => {
    chrome.storage.local.remove(
      [CONFIG_KEYS.CRM_URL, CONFIG_KEYS.JWT_TOKEN],
      () => {
        if (chrome.runtime.lastError) {
          reject(new Error(chrome.runtime.lastError.message));
        } else {
          resolve();
        }
      }
    );
  });
}
