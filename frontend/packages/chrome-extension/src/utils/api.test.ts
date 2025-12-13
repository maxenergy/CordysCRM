/**
 * API 请求格式属性测试
 * **Feature: crm-mobile-enterprise-ai, Property 7: API请求格式正确性**
 * **Validates: Requirements 2.4**
 */

import { describe, it, expect } from 'vitest';
import * as fc from 'fast-check';
import type { CRMConfig, EnterpriseImportRequest } from '../types/config';

// 生成有效的统一社会信用代码
const creditCodeArbitrary = fc.stringOf(
  fc.constantFrom(
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K',
    'L', 'M', 'N', 'P', 'Q', 'R', 'T', 'U', 'W', 'X', 'Y'
  ),
  { minLength: 18, maxLength: 18 }
).map((s) => '91' + s.slice(2));

// 生成企业名称
const companyNameArbitrary = fc.string({ minLength: 2, maxLength: 50 })
  .filter((s) => s.trim().length >= 2);

// 生成 JWT Token
const jwtTokenArbitrary = fc.string({ minLength: 20, maxLength: 500 })
  .filter((s) => !s.includes(' '));

// 生成 CRM URL
const crmUrlArbitrary = fc.webUrl();

// 生成企业导入请求
const enterpriseImportRequestArbitrary = fc.record({
  companyName: companyNameArbitrary,
  creditCode: creditCodeArbitrary,
  legalPerson: fc.option(fc.string({ minLength: 2, maxLength: 20 }), { nil: undefined }),
  registeredCapital: fc.option(fc.string({ minLength: 1, maxLength: 50 }), { nil: undefined }),
  establishmentDate: fc.option(
    fc.date({ min: new Date('1990-01-01'), max: new Date('2024-01-01') })
      .map((d) => d.toISOString().split('T')[0]),
    { nil: undefined }
  ),
  address: fc.option(fc.string({ minLength: 5, maxLength: 200 }), { nil: undefined }),
  industry: fc.option(fc.string({ minLength: 2, maxLength: 50 }), { nil: undefined }),
  staffSize: fc.option(fc.string({ minLength: 2, maxLength: 20 }), { nil: undefined }),
  phone: fc.option(fc.stringOf(fc.constantFrom('0', '1', '2', '3', '4', '5', '6', '7', '8', '9'), { minLength: 11, maxLength: 11 }), { nil: undefined }),
  customerId: fc.option(fc.integer({ min: 1, max: 1000000 }), { nil: undefined }),
  source: fc.constant('chrome_extension' as const),
});

/**
 * 模拟发送企业导入请求
 * 这个函数模拟 background.ts 中的 API 调用逻辑
 */
async function sendEnterpriseImportRequest(
  config: CRMConfig,
  data: EnterpriseImportRequest
): Promise<{
  url: string;
  method: string;
  headers: Record<string, string>;
  body: string;
}> {
  const baseUrl = config.crmUrl.replace(/\/+$/, '');
  const url = `${baseUrl}/api/enterprise/import`;

  const headers: Record<string, string> = {
    'Authorization': `Bearer ${config.jwtToken}`,
    'Content-Type': 'application/json',
  };

  const body = JSON.stringify(data);

  return { url, method: 'POST', headers, body };
}

describe('API Request Format Property Tests', () => {
  /**
   * Property 7: API请求格式正确性
   * For any Chrome Extension 发送的企业数据，请求应该包含正确的 Authorization 头和 JSON 格式的请求体。
   */
  it('should include correct Authorization header and JSON body (Property 7)', async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.record({
          crmUrl: crmUrlArbitrary,
          jwtToken: jwtTokenArbitrary,
        }),
        enterpriseImportRequestArbitrary,
        async (config: CRMConfig, data: EnterpriseImportRequest) => {
          const request = await sendEnterpriseImportRequest(config, data);

          // Verify Authorization header format
          expect(request.headers['Authorization']).toBeDefined();
          expect(request.headers['Authorization']).toBe(`Bearer ${config.jwtToken}`);
          expect(request.headers['Authorization']).toMatch(/^Bearer .+$/);

          // Verify Content-Type header
          expect(request.headers['Content-Type']).toBe('application/json');

          // Verify request method
          expect(request.method).toBe('POST');

          // Verify URL format
          expect(request.url).toContain('/api/enterprise/import');
          expect(request.url).not.toContain('//api'); // No double slashes

          // Verify body is valid JSON
          expect(() => JSON.parse(request.body)).not.toThrow();

          // Verify body contains required fields
          const parsedBody = JSON.parse(request.body);
          expect(parsedBody.companyName).toBe(data.companyName);
          expect(parsedBody.creditCode).toBe(data.creditCode);
          expect(parsedBody.source).toBe('chrome_extension');
        }
      ),
      { numRuns: 100 }
    );
  });

  /**
   * Property: URL 末尾斜杠处理
   * 无论 CRM URL 是否以斜杠结尾，生成的请求 URL 应该格式正确
   */
  it('should handle trailing slashes in CRM URL correctly', async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.record({
          crmUrl: fc.oneof(
            crmUrlArbitrary,
            crmUrlArbitrary.map((url) => url + '/'),
            crmUrlArbitrary.map((url) => url + '//'),
          ),
          jwtToken: jwtTokenArbitrary,
        }),
        enterpriseImportRequestArbitrary,
        async (config: CRMConfig, data: EnterpriseImportRequest) => {
          const request = await sendEnterpriseImportRequest(config, data);

          // URL should not have double slashes before /api
          expect(request.url).not.toMatch(/[^:]\/\/api/);

          // URL should end with /api/enterprise/import
          expect(request.url).toMatch(/\/api\/enterprise\/import$/);
        }
      ),
      { numRuns: 50 }
    );
  });

  /**
   * Property: 请求体字段完整性
   * 所有提供的字段都应该出现在请求体中
   */
  it('should include all provided fields in request body', async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.record({
          crmUrl: crmUrlArbitrary,
          jwtToken: jwtTokenArbitrary,
        }),
        enterpriseImportRequestArbitrary,
        async (config: CRMConfig, data: EnterpriseImportRequest) => {
          const request = await sendEnterpriseImportRequest(config, data);
          const parsedBody = JSON.parse(request.body);

          // Check all fields
          Object.entries(data).forEach(([key, value]) => {
            if (value !== undefined) {
              expect(parsedBody[key]).toBe(value);
            }
          });
        }
      ),
      { numRuns: 50 }
    );
  });

  /**
   * Property: Token 不应该被修改
   * Authorization 头中的 Token 应该与配置中的完全一致
   */
  it('should not modify JWT token in Authorization header', async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.record({
          crmUrl: crmUrlArbitrary,
          jwtToken: fc.string({ minLength: 50, maxLength: 500 }),
        }),
        enterpriseImportRequestArbitrary,
        async (config: CRMConfig, data: EnterpriseImportRequest) => {
          const request = await sendEnterpriseImportRequest(config, data);

          // Extract token from Authorization header
          const authHeader = request.headers['Authorization'];
          const extractedToken = authHeader.replace('Bearer ', '');

          // Token should be exactly the same
          expect(extractedToken).toBe(config.jwtToken);
        }
      ),
      { numRuns: 50 }
    );
  });

  /**
   * Property: 请求体 JSON 序列化往返一致性
   * 序列化后再解析应该得到相同的数据
   */
  it('should preserve data through JSON serialization round-trip', async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.record({
          crmUrl: crmUrlArbitrary,
          jwtToken: jwtTokenArbitrary,
        }),
        enterpriseImportRequestArbitrary,
        async (config: CRMConfig, data: EnterpriseImportRequest) => {
          const request = await sendEnterpriseImportRequest(config, data);
          const parsedBody = JSON.parse(request.body) as EnterpriseImportRequest;

          // Required fields
          expect(parsedBody.companyName).toBe(data.companyName);
          expect(parsedBody.creditCode).toBe(data.creditCode);
          expect(parsedBody.source).toBe(data.source);

          // Optional fields (only check if defined)
          if (data.legalPerson !== undefined) {
            expect(parsedBody.legalPerson).toBe(data.legalPerson);
          }
          if (data.registeredCapital !== undefined) {
            expect(parsedBody.registeredCapital).toBe(data.registeredCapital);
          }
          if (data.establishmentDate !== undefined) {
            expect(parsedBody.establishmentDate).toBe(data.establishmentDate);
          }
          if (data.address !== undefined) {
            expect(parsedBody.address).toBe(data.address);
          }
          if (data.industry !== undefined) {
            expect(parsedBody.industry).toBe(data.industry);
          }
          if (data.staffSize !== undefined) {
            expect(parsedBody.staffSize).toBe(data.staffSize);
          }
          if (data.phone !== undefined) {
            expect(parsedBody.phone).toBe(data.phone);
          }
          if (data.customerId !== undefined) {
            expect(parsedBody.customerId).toBe(data.customerId);
          }
        }
      ),
      { numRuns: 50 }
    );
  });
});
