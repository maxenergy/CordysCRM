/**
 * 企业导入相关类型定义
 */

// 企业搜索结果
export interface EnterpriseSearchResult {
  id: string;
  name: string;
  creditCode: string;
  legalPerson: string;
  registeredCapital: string;
  establishDate: string;
  status: string;
  address: string;
  industry: string;
  aiqichaUrl?: string;
}

// 企业导入请求参数
export interface EnterpriseImportParams {
  name: string;
  creditCode?: string;
  legalPerson?: string;
  registeredCapital?: string;
  establishDate?: string;
  address?: string;
  industry?: string;
  staffSize?: string;
  businessScope?: string;
  source?: string;
  aiqichaUrl?: string;
  // 关联选项
  linkToCustomerId?: string;
  createAsCustomer?: boolean;
}

// 企业导入响应
export interface EnterpriseImportResponse {
  success: boolean;
  customerId?: string;
  enterpriseProfileId?: string;
  message?: string;
  conflicts?: EnterpriseConflict[];
}

// 企业冲突信息
export interface EnterpriseConflict {
  field: string;
  existingValue: string;
  newValue: string;
}

// 企业检查结果
export interface EnterpriseCheckResult {
  exists: boolean;
  customerId?: string;
  customerName?: string;
}
