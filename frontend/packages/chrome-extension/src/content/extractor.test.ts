/**
 * DOM 数据提取属性测试
 * **Feature: crm-mobile-enterprise-ai, Property 6: DOM数据提取完整性**
 * **Validates: Requirements 2.3**
 */

import { describe, it, expect, beforeEach } from 'vitest';
import * as fc from 'fast-check';
import { JSDOM } from 'jsdom';
import { extractEnterpriseData, validateExtractedData } from './extractor';

// 生成有效的统一社会信用代码（18位）
const creditCodeArbitrary = fc.stringOf(
  fc.constantFrom(
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K',
    'L', 'M', 'N', 'P', 'Q', 'R', 'T', 'U', 'W', 'X', 'Y'
  ),
  { minLength: 18, maxLength: 18 }
).map((s) => {
  // 确保前两位是有效的登记管理部门代码
  const prefix = fc.sample(fc.constantFrom('11', '12', '13', '91', '92', '93'), 1)[0];
  return prefix + s.slice(2);
});

// 生成中文企业名称
const companyNameArbitrary = fc.stringOf(
  fc.constantFrom(
    '中', '国', '华', '东', '南', '西', '北', '科', '技', '信', '息',
    '网', '络', '电', '子', '商', '务', '贸', '易', '投', '资', '金',
    '融', '建', '设', '工', '程', '材', '料', '机', '械', '制', '造'
  ),
  { minLength: 2, maxLength: 20 }
).map((s) => s + fc.sample(fc.constantFrom('有限公司', '股份有限公司', '集团有限公司', '科技有限公司'), 1)[0]);

// 生成法定代表人姓名
const legalPersonArbitrary = fc.stringOf(
  fc.constantFrom(
    '张', '王', '李', '赵', '刘', '陈', '杨', '黄', '周', '吴',
    '明', '华', '强', '伟', '芳', '娜', '秀', '英', '敏', '静'
  ),
  { minLength: 2, maxLength: 4 }
);

// 生成注册资本
const registeredCapitalArbitrary = fc.integer({ min: 10, max: 100000000 })
  .map((n) => `${n}万人民币`);

// 生成成立日期
const establishmentDateArbitrary = fc.date({
  min: new Date('1990-01-01'),
  max: new Date('2024-01-01'),
}).map((d) => d.toISOString().split('T')[0]);

// 生成地址
const addressArbitrary = fc.constantFrom(
  '北京市朝阳区建国路88号',
  '上海市浦东新区陆家嘴环路1000号',
  '广州市天河区珠江新城华夏路30号',
  '深圳市南山区科技园南区高新南一道',
  '杭州市西湖区文三路398号'
);

// 生成行业
const industryArbitrary = fc.constantFrom(
  '信息传输、软件和信息技术服务业',
  '制造业',
  '批发和零售业',
  '金融业',
  '房地产业',
  '科学研究和技术服务业'
);

// 生成人员规模
const staffSizeArbitrary = fc.constantFrom(
  '小于50人',
  '50-99人',
  '100-499人',
  '500-999人',
  '1000人以上'
);

// 生成电话
const phoneArbitrary = fc.stringOf(fc.constantFrom('0', '1', '2', '3', '4', '5', '6', '7', '8', '9'), { minLength: 11, maxLength: 11 })
  .map((s) => s.startsWith('1') ? s : '1' + s.slice(1));

/**
 * 创建模拟的爱企查企业详情页 HTML
 */
function createMockAiqichaPage(data: {
  companyName: string;
  creditCode: string;
  legalPerson?: string;
  registeredCapital?: string;
  establishmentDate?: string;
  address?: string;
  industry?: string;
  staffSize?: string;
  phone?: string;
}): string {
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <title>${data.companyName} - 爱企查</title>
    </head>
    <body>
      <div class="company-header">
        <h1 class="company-name">${data.companyName}</h1>
      </div>
      <div class="basic-info">
        <div class="info-item">
          <span class="label">统一社会信用代码：</span>
          <span class="value">${data.creditCode}</span>
        </div>
        ${data.legalPerson ? `
        <div class="info-item">
          <span class="label">法定代表人：</span>
          <span class="value">${data.legalPerson}</span>
        </div>
        ` : ''}
        ${data.registeredCapital ? `
        <div class="info-item">
          <span class="label">注册资本：</span>
          <span class="value">${data.registeredCapital}</span>
        </div>
        ` : ''}
        ${data.establishmentDate ? `
        <div class="info-item">
          <span class="label">成立日期：</span>
          <span class="value">${data.establishmentDate}</span>
        </div>
        ` : ''}
        ${data.address ? `
        <div class="info-item">
          <span class="label">注册地址：</span>
          <span class="value">${data.address}</span>
        </div>
        ` : ''}
        ${data.industry ? `
        <div class="info-item">
          <span class="label">所属行业：</span>
          <span class="value">${data.industry}</span>
        </div>
        ` : ''}
        ${data.staffSize ? `
        <div class="info-item">
          <span class="label">人员规模：</span>
          <span class="value">${data.staffSize}</span>
        </div>
        ` : ''}
        ${data.phone ? `
        <div class="info-item">
          <span class="label">联系电话：</span>
          <span class="value">${data.phone}</span>
        </div>
        ` : ''}
      </div>
    </body>
    </html>
  `;
}

/**
 * 设置 JSDOM 环境
 */
function setupDOM(html: string): void {
  const dom = new JSDOM(html, { url: 'https://aiqicha.baidu.com/company_detail_12345' });
  global.document = dom.window.document;
  global.window = dom.window as unknown as Window & typeof globalThis;
}

describe('DOM Data Extraction Property Tests', () => {
  /**
   * Property 6: DOM数据提取完整性
   * For any 有效的爱企查企业详情页 HTML，Chrome Extension 应该能够提取出企业名称和统一社会信用代码（必填字段）。
   */
  it('should extract company name and credit code from valid Aiqicha page (Property 6)', () => {
    fc.assert(
      fc.property(
        fc.record({
          companyName: companyNameArbitrary,
          creditCode: creditCodeArbitrary,
          legalPerson: fc.option(legalPersonArbitrary, { nil: undefined }),
          registeredCapital: fc.option(registeredCapitalArbitrary, { nil: undefined }),
          establishmentDate: fc.option(establishmentDateArbitrary, { nil: undefined }),
          address: fc.option(addressArbitrary, { nil: undefined }),
          industry: fc.option(industryArbitrary, { nil: undefined }),
          staffSize: fc.option(staffSizeArbitrary, { nil: undefined }),
          phone: fc.option(phoneArbitrary, { nil: undefined }),
        }),
        (data) => {
          // Setup DOM with mock page
          const html = createMockAiqichaPage(data);
          setupDOM(html);

          // Extract data
          const extracted = extractEnterpriseData();

          // Verify required fields are extracted
          expect(extracted.companyName).toBe(data.companyName);
          expect(extracted.creditCode).toBe(data.creditCode);

          // Verify validation passes for required fields
          const validation = validateExtractedData(extracted);
          expect(validation.valid).toBe(true);
          expect(validation.errors).toHaveLength(0);
        }
      ),
      { numRuns: 100 }
    );
  });

  /**
   * Property: 可选字段提取
   * 当页面包含可选字段时，应该能够正确提取
   */
  it('should extract optional fields when present', () => {
    fc.assert(
      fc.property(
        fc.record({
          companyName: companyNameArbitrary,
          creditCode: creditCodeArbitrary,
          legalPerson: legalPersonArbitrary,
          registeredCapital: registeredCapitalArbitrary,
          establishmentDate: establishmentDateArbitrary,
          address: addressArbitrary,
          industry: industryArbitrary,
          staffSize: staffSizeArbitrary,
          phone: phoneArbitrary,
        }),
        (data) => {
          const html = createMockAiqichaPage(data);
          setupDOM(html);

          const extracted = extractEnterpriseData();

          // Verify all fields are extracted
          expect(extracted.companyName).toBe(data.companyName);
          expect(extracted.creditCode).toBe(data.creditCode);
          expect(extracted.legalPerson).toBe(data.legalPerson);
          expect(extracted.registeredCapital).toBe(data.registeredCapital);
          expect(extracted.establishmentDate).toBe(data.establishmentDate);
          expect(extracted.address).toBe(data.address);
          expect(extracted.industry).toBe(data.industry);
          expect(extracted.staffSize).toBe(data.staffSize);
          expect(extracted.phone).toBe(data.phone);
        }
      ),
      { numRuns: 50 }
    );
  });

  /**
   * Property: 信用代码格式验证
   * 提取的信用代码应该符合18位格式
   */
  it('should validate credit code format', () => {
    fc.assert(
      fc.property(
        fc.record({
          companyName: companyNameArbitrary,
          creditCode: creditCodeArbitrary,
        }),
        (data) => {
          const html = createMockAiqichaPage(data);
          setupDOM(html);

          const extracted = extractEnterpriseData();
          const validation = validateExtractedData(extracted);

          // Credit code should be 18 characters
          expect(extracted.creditCode).toHaveLength(18);
          expect(validation.valid).toBe(true);
        }
      ),
      { numRuns: 50 }
    );
  });

  /**
   * Property: 无效信用代码检测
   * 当信用代码格式不正确时，验证应该失败
   */
  it('should detect invalid credit code format', () => {
    const invalidCreditCodes = [
      '12345', // 太短
      '123456789012345678901', // 太长
      '12345678901234567!', // 包含特殊字符
    ];

    invalidCreditCodes.forEach((invalidCode) => {
      const html = createMockAiqichaPage({
        companyName: '测试公司有限公司',
        creditCode: invalidCode,
      });
      setupDOM(html);

      const extracted = extractEnterpriseData();
      const validation = validateExtractedData(extracted);

      expect(validation.valid).toBe(false);
      expect(validation.errors.length).toBeGreaterThan(0);
    });
  });

  /**
   * Property: 缺失必填字段检测
   * 当缺少企业名称或信用代码时，验证应该失败
   */
  it('should detect missing required fields', () => {
    // Test validation with empty data
    const emptyData = {
      companyName: '',
      creditCode: '',
      source: 'chrome_extension' as const,
    };
    
    let validation = validateExtractedData(emptyData);
    expect(validation.valid).toBe(false);
    expect(validation.errors).toContain('未能提取企业名称');
    expect(validation.errors).toContain('未能提取统一社会信用代码');

    // Test validation with only company name
    const onlyNameData = {
      companyName: '测试公司有限公司',
      creditCode: '',
      source: 'chrome_extension' as const,
    };
    
    validation = validateExtractedData(onlyNameData);
    expect(validation.valid).toBe(false);
    expect(validation.errors).toContain('未能提取统一社会信用代码');
    expect(validation.errors).not.toContain('未能提取企业名称');

    // Test validation with only credit code
    const onlyCodeData = {
      companyName: '',
      creditCode: '91110000MA00ABCD12',
      source: 'chrome_extension' as const,
    };
    
    validation = validateExtractedData(onlyCodeData);
    expect(validation.valid).toBe(false);
    expect(validation.errors).toContain('未能提取企业名称');
    expect(validation.errors).not.toContain('未能提取统一社会信用代码');
  });
});
