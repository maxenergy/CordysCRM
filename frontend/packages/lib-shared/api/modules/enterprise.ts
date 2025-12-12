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
   * 检查扩展是否可用（通过 content script 注入的 meta 标签）
   */
  function isExtensionAvailable(): boolean {
    const meta = document.querySelector<HTMLMetaElement>('meta[name="aiqicha-extension-ready"]');
    return meta?.content === 'true';
  }

  /**
   * 等待扩展就绪（通过 postMessage ping/pong）
   */
  function waitForExtension(timeout = 1500): Promise<boolean> {
    return new Promise((resolve) => {
      // 先检查 meta 标签
      if (isExtensionAvailable()) {
        resolve(true);
        return;
      }

      let resolved = false;
      let timeoutId: ReturnType<typeof setTimeout>;

      // 监听 pong 响应
      const handler = (event: MessageEvent) => {
        // 安全检查：只接受来自同源的消息
        if (event.origin !== location.origin || event.source !== window) {
          return;
        }
        if (event.data?.type === 'AIQICHA_EXTENSION_PONG' && event.data?.available) {
          resolved = true;
          clearTimeout(timeoutId);
          window.removeEventListener('message', handler);
          resolve(true);
        }
      };
      window.addEventListener('message', handler);

      // 发送 ping 请求（指定 targetOrigin）
      window.postMessage({ type: 'AIQICHA_EXTENSION_PING' }, location.origin);

      // 超时处理
      timeoutId = setTimeout(() => {
        if (!resolved) {
          window.removeEventListener('message', handler);
          // 最后再检查一次 meta 标签
          resolve(isExtensionAvailable());
        }
      }, timeout);
    });
  }

  /** 生成唯一请求 ID */
  function generateRequestId(): string {
    return `${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
  }

  /**
   * 通过 Chrome 扩展搜索爱企查企业
   * 使用 window.postMessage 与 content script 通信，更安全可靠
   * @param keyword 搜索关键词
   * @param page 页码
   * @param pageSize 每页数量
   */
  async function searchEnterpriseViaExtension(
    keyword: string,
    page = 1,
    pageSize = 20
  ): Promise<EnterpriseSearchResponse> {
    // 检查扩展是否可用
    const available = await waitForExtension(1000);
    
    if (!available) {
      return {
        success: false,
        message: '请安装并启用"爱企查 CRM 助手"Chrome 扩展，然后刷新页面',
        items: [],
        total: 0,
        errorCode: 'EXT_UNAVAILABLE',
      };
    }

    const requestId = generateRequestId();
    const REQUEST_TIMEOUT = 15000; // 15 秒超时

    return new Promise<EnterpriseSearchResponse>((resolve) => {
      let resolved = false;
      let timeoutId: ReturnType<typeof setTimeout>;

      // 监听响应
      const handler = (event: MessageEvent) => {
        // 安全检查：只接受来自同源的消息
        if (event.origin !== location.origin || event.source !== window) {
          return;
        }
        
        const data = event.data;
        if (data?.type === 'AIQICHA_SEARCH_RESPONSE' && data?.requestId === requestId) {
          resolved = true;
          clearTimeout(timeoutId);
          window.removeEventListener('message', handler);
          
          if (data.success) {
            resolve({
              success: true,
              items: (data.items || []).map((item: Record<string, unknown>) => ({
                pid: String(item?.pid || ''),
                name: String(item?.name || ''),
                creditCode: item?.creditCode as string | undefined,
                legalPerson: item?.legalPerson as string | undefined,
                address: item?.address as string | undefined,
                status: item?.status as string | undefined,
                establishDate: item?.establishDate as string | undefined,
                registeredCapital: item?.registeredCapital as string | undefined,
                industry: item?.industry as string | undefined,
              })),
              total: Number(data.total || 0),
            });
          } else {
            resolve({
              success: false,
              message: data.message || '搜索失败',
              items: [],
              total: 0,
            });
          }
        }
      };
      window.addEventListener('message', handler);

      // 发送搜索请求（指定 targetOrigin）
      // eslint-disable-next-line no-console
      console.log('[Enterprise Search] Sending search request via postMessage');
      window.postMessage({
        type: 'AIQICHA_SEARCH_REQUEST',
        requestId,
        keyword,
        page,
        pageSize,
      }, location.origin);

      // 超时处理
      timeoutId = setTimeout(() => {
        if (!resolved) {
          window.removeEventListener('message', handler);
          resolve({
            success: false,
            message: '搜索请求超时，请重试',
            items: [],
            total: 0,
            errorCode: 'EXT_NO_RESPONSE',
          });
        }
      }, REQUEST_TIMEOUT);
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
