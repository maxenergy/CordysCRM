/**
 * Chrome Extension 配置类型定义
 */

/** CRM 连接配置 */
export interface CRMConfig {
  /** CRM 系统地址 */
  crmUrl: string;
  /** JWT 认证令牌 */
  jwtToken: string;
}

/** 配置存储键名 */
export const CONFIG_KEYS = {
  CRM_URL: 'crmUrl',
  JWT_TOKEN: 'jwtToken',
} as const;

/** 连接测试响应 */
export interface ConnectionTestResult {
  success: boolean;
  message: string;
  statusCode?: number;
}

/** 企业导入请求 */
export interface EnterpriseImportRequest {
  companyName: string;
  creditCode: string;
  legalPerson?: string;
  registeredCapital?: string;
  establishmentDate?: string;
  address?: string;
  industry?: string;
  staffSize?: string;
  phone?: string;
  customerId?: number;
  source: 'chrome_extension' | 'webview' | 'manual';
}

/** 企业导入响应 */
export interface EnterpriseImportResponse {
  success: boolean;
  customerId?: number;
  isNew?: boolean;
  conflicts?: ConflictField[];
  message?: string;
}

/** 冲突字段 */
export interface ConflictField {
  field: string;
  localValue: string;
  remoteValue: string;
}
