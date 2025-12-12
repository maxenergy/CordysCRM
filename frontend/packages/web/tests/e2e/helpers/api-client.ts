import type { APIRequestContext } from '@playwright/test';

/**
 * 测试 API 客户端
 * 用于测试数据的创建、验证和清理
 */
export class TestApiClient {
  private request: APIRequestContext;
  private baseUrl: string;
  private authToken?: string;

  constructor(request: APIRequestContext, baseUrl: string) {
    this.request = request;
    this.baseUrl = baseUrl;
  }

  /**
   * 设置认证 Token
   */
  setAuthToken(token: string): void {
    this.authToken = token;
  }

  /**
   * 获取请求头
   */
  private getHeaders(): Record<string, string> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    };
    if (this.authToken) {
      headers['Authorization'] = `Bearer ${this.authToken}`;
    }
    return headers;
  }

  /**
   * 登录并获取 Token
   */
  async login(username: string, password: string): Promise<string> {
    const response = await this.request.post(`${this.baseUrl}/api/auth/login`, {
      headers: { 'Content-Type': 'application/json' },
      data: { username, password },
    });

    if (!response.ok()) {
      throw new Error(`Login failed: ${response.status()}`);
    }

    const data = await response.json();
    this.authToken = data.token || data.data?.token;
    return this.authToken!;
  }

  /**
   * 导入企业
   */
  async importEnterprise(data: {
    companyName: string;
    creditCode?: string;
    legalPerson?: string;
    address?: string;
    industry?: string;
    source?: string;
  }): Promise<{ success: boolean; customerId?: string; message?: string }> {
    const response = await this.request.post(`${this.baseUrl}/api/enterprise/import`, {
      headers: this.getHeaders(),
      data: {
        ...data,
        source: data.source || 'E2E_TEST', // 标记为测试数据
      },
    });

    return response.json();
  }

  /**
   * 查询企业（通过统一社会信用代码）
   */
  async findEnterpriseByCreditCode(creditCode: string): Promise<{
    found: boolean;
    enterprise?: {
      id: string;
      companyName: string;
      creditCode: string;
      legalPerson?: string;
      address?: string;
    };
  }> {
    const response = await this.request.get(
      `${this.baseUrl}/api/enterprise/search?creditCode=${encodeURIComponent(creditCode)}`,
      { headers: this.getHeaders() }
    );

    if (!response.ok()) {
      return { found: false };
    }

    const data = await response.json();
    const items = data.items || data.data?.items || [];
    const enterprise = items.find((e: { creditCode?: string }) => e.creditCode === creditCode);

    return {
      found: !!enterprise,
      enterprise,
    };
  }

  /**
   * 删除企业（测试清理用）
   */
  async deleteEnterprise(id: string): Promise<boolean> {
    const response = await this.request.delete(`${this.baseUrl}/api/enterprise/${id}`, {
      headers: this.getHeaders(),
    });
    return response.ok();
  }

  /**
   * 清理测试数据（按 source 标记）
   */
  async cleanupTestData(): Promise<number> {
    const response = await this.request.delete(`${this.baseUrl}/api/test/cleanup?source=E2E_TEST`, {
      headers: this.getHeaders(),
    });

    if (!response.ok()) {
      console.warn('Cleanup endpoint not available, skipping...');
      return 0;
    }

    const data = await response.json();
    return data.deletedCount || 0;
  }

  /**
   * 查询客户列表
   */
  async getCustomers(params?: {
    keyword?: string;
    page?: number;
    pageSize?: number;
  }): Promise<{
    items: Array<{
      id: string;
      companyName: string;
      creditCode?: string;
    }>;
    total: number;
  }> {
    const searchParams = new URLSearchParams();
    if (params?.keyword) searchParams.set('keyword', params.keyword);
    if (params?.page) searchParams.set('page', String(params.page));
    if (params?.pageSize) searchParams.set('pageSize', String(params.pageSize));

    const response = await this.request.get(
      `${this.baseUrl}/api/customer/list?${searchParams.toString()}`,
      { headers: this.getHeaders() }
    );

    const data = await response.json();
    return {
      items: data.items || data.data?.items || [],
      total: data.total || data.data?.total || 0,
    };
  }
}

/**
 * 生成唯一的测试数据标识
 */
export function generateTestId(): string {
  const timestamp = Date.now();
  const random = Math.random().toString(36).slice(2, 8);
  return `E2E_${timestamp}_${random}`;
}

/**
 * 生成测试用的统一社会信用代码
 */
export function generateTestCreditCode(): string {
  const testId = generateTestId();
  // 格式: 91 + 6位行政区划 + 9位组织机构代码 + 1位校验码
  return `91440300${testId.slice(0, 9).toUpperCase()}X`;
}
