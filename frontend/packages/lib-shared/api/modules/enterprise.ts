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
  /** 错误码，用于判断是否需要回退到后端 API */
  errorCode?: 'EXT_UNAVAILABLE' | 'EXT_COMMUNICATION_ERROR' | 'EXT_NO_RESPONSE';
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
   * 搜索爱企查企业（通过后端 API）
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
   * 通过 Chrome 扩展搜索爱企查企业
   * 利用用户浏览器环境绑过反爬虫机制
   * @param keyword 搜索关键词
   * @param page 页码
   * @param pageSize 每页数量
   * @param extensionId 扩展 ID（可选，用于 externally_connectable）
   */
  async function searchEnterpriseViaExtension(
    keyword: string,
    page = 1,
    pageSize = 20,
    extensionId?: string
  ): Promise<EnterpriseSearchResponse> {
    // 检查 Chrome 扩展是否可用
    const runtime = (globalThis as { chrome?: { runtime?: unknown } })?.chrome?.runtime as
      | {
          sendMessage: (
            extensionIdOrMessage: string | object,
            messageOrCallback: object | ((response: unknown) => void),
            callback?: (response: unknown) => void
          ) => void;
          lastError?: { message?: string };
        }
      | undefined;

    if (!runtime?.sendMessage) {
      return {
        success: false,
        message: '请安装并启用"爱企查 CRM 助手"Chrome 扩展',
        items: [],
        total: 0,
        errorCode: 'EXT_UNAVAILABLE',
      };
    }

    const payload = {
      type: 'SEARCH_AIQICHA',
      keyword,
      page,
      pageSize,
    };

    return new Promise<EnterpriseSearchResponse>((resolve) => {
      const callback = (response: unknown) => {
        const lastError = runtime?.lastError;
        if (lastError) {
          resolve({
            success: false,
            message: lastError.message || '扩展通信失败，请确保扩展已启用',
            items: [],
            total: 0,
            errorCode: 'EXT_COMMUNICATION_ERROR',
          });
          return;
        }

        if (!response) {
          resolve({
            success: false,
            message: '扩展未响应，请确保扩展已正确安装',
            items: [],
            total: 0,
            errorCode: 'EXT_NO_RESPONSE',
          });
          return;
        }

        resolve(response as EnterpriseSearchResponse);
      };

      // 如果提供了扩展 ID，使用 externally_connectable 方式
      if (extensionId) {
        runtime.sendMessage(extensionId, payload, callback);
      } else {
        // 否则尝试直接发送（需要在扩展的 content script 中）
        runtime.sendMessage(payload, callback);
      }
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
    return CDR.post<{ success: boolean; message?: string }>({
      url: EnterpriseCookieUrl,
      data: { cookie },
    });
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
    searchEnterpriseViaExtension,
    getEnterpriseDetail,
    importEnterprise,
    saveIqichaCookie,
    checkIqichaCookieStatus,
  };
}
