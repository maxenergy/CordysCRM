import type { CordysAxios } from '@lib/shared/api/http/Axios';

/** 企业搜索 API URLs */
const EnterpriseSearchUrl = '/api/enterprise/search';
const EnterpriseDetailUrl = '/api/enterprise/detail';
const EnterpriseImportUrl = '/api/enterprise/import';
const EnterpriseCookieUrl = '/api/enterprise/config/cookie';
const EnterpriseCookieStatusUrl = '/api/enterprise/config/cookie/status';

/** 企业搜索结果项 */
export interface EnterpriseSearchItem {
  pid: string;
  name: string;
  creditCode?: string;
  legalPerson?: string;
  address?: string;
  status?: string;
  establishDate?: string;
  registeredCapital?: string;
  industry?: string;
}

/** 企业搜索响应 */
export interface EnterpriseSearchResponse {
  success: boolean;
  message?: string;
  items: EnterpriseSearchItem[];
  total: number;
}

/** 企业详情 */
export interface EnterpriseDetail extends EnterpriseSearchItem {
  phone?: string;
  email?: string;
  website?: string;
  scope?: string;
}

export default function useEnterpriseApi(CDR: CordysAxios) {
  /**
   * 搜索爱企查企业
   */
  async function searchEnterprise(
    keyword: string,
    page = 1,
    pageSize = 20
  ): Promise<EnterpriseSearchResponse> {
    return CDR.get<EnterpriseSearchResponse>({
      url: EnterpriseSearchUrl,
      params: { keyword, page, pageSize },
    });
  }

  /**
   * 获取企业详情
   */
  async function getEnterpriseDetail(pid: string): Promise<EnterpriseDetail | null> {
    return CDR.get<EnterpriseDetail | null>({
      url: `${EnterpriseDetailUrl}/${pid}`,
    });
  }

  /**
   * 导入企业到 CRM
   */
  async function importEnterprise(data: {
    companyName: string;
    creditCode?: string;
    legalPerson?: string;
    address?: string;
    industry?: string;
  }): Promise<{ success: boolean; message?: string; customerId?: string }> {
    return CDR.post({
      url: EnterpriseImportUrl,
      data,
    });
  }

  /**
   * 保存爱企查 Cookie
   */
  async function saveIqichaCookie(
    cookie: string
  ): Promise<{ success: boolean; message?: string }> {
    console.log('[DEBUG API] 发送保存Cookie请求, URL:', EnterpriseCookieUrl);
    console.log('[DEBUG API] 请求数据:', { cookie: cookie.substring(0, 50) + '...' });
    try {
      const result = await CDR.post<{ success: boolean; message?: string }>({
        url: EnterpriseCookieUrl,
        data: { cookie },
      });
      console.log('[DEBUG API] 响应结果:', result);
      return result;
    } catch (error) {
      console.error('[DEBUG API] 请求异常:', error);
      throw error;
    }
  }

  /**
   * 检查爱企查 Cookie 配置状态
   */
  async function checkIqichaCookieStatus(): Promise<{ configured: boolean }> {
    return CDR.get({
      url: EnterpriseCookieStatusUrl,
    });
  }

  return {
    searchEnterprise,
    getEnterpriseDetail,
    importEnterprise,
    saveIqichaCookie,
    checkIqichaCookieStatus,
  };
}
