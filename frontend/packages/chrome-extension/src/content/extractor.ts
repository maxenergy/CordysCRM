/**
 * DOM 数据提取器
 * 从爱企查企业详情页提取企业信息
 */

import type { EnterpriseImportRequest } from '../types/config';

/** 企业信息选择器配置 */
const SELECTORS = {
  // 企业名称 - 页面标题区域
  companyName: [
    '.company-header .company-name',
    '.header-content .title',
    'h1.company-name',
    '.basic-info .name',
  ],
  // 基本信息表格
  infoTable: [
    '.basic-info-table',
    '.company-info-table',
    '.info-table',
    'table.basic-info',
  ],
  // 信息项
  infoItem: [
    '.info-item',
    '.basic-item',
    'tr',
  ],
};

/** 可提取的字段类型 */
type ExtractableField = 'companyName' | 'creditCode' | 'legalPerson' | 'registeredCapital' | 
  'establishmentDate' | 'address' | 'industry' | 'staffSize' | 'phone';

/** 字段映射 - 中文标签到字段名 */
const FIELD_MAPPING: Record<string, ExtractableField> = {
  '统一社会信用代码': 'creditCode',
  '社会信用代码': 'creditCode',
  '信用代码': 'creditCode',
  '法定代表人': 'legalPerson',
  '法人': 'legalPerson',
  '法人代表': 'legalPerson',
  '注册资本': 'registeredCapital',
  '注册资金': 'registeredCapital',
  '成立日期': 'establishmentDate',
  '成立时间': 'establishmentDate',
  '注册地址': 'address',
  '企业地址': 'address',
  '经营地址': 'address',
  '所属行业': 'industry',
  '行业': 'industry',
  '人员规模': 'staffSize',
  '员工人数': 'staffSize',
  '企业规模': 'staffSize',
  '联系电话': 'phone',
  '电话': 'phone',
};

/**
 * 查找元素（尝试多个选择器）
 */
function findElement(selectors: string[]): Element | null {
  for (const selector of selectors) {
    const element = document.querySelector(selector);
    if (element) {
      return element;
    }
  }
  return null;
}

/**
 * 获取元素文本内容（清理空白字符）
 */
function getTextContent(element: Element | null): string {
  if (!element) return '';
  return element.textContent?.trim().replace(/\s+/g, ' ') || '';
}

/**
 * 提取企业名称
 */
function extractCompanyName(): string {
  // 尝试从多个位置提取
  const element = findElement(SELECTORS.companyName);
  if (element) {
    return getTextContent(element);
  }

  // 尝试从页面标题提取
  const title = document.title;
  const match = title.match(/^(.+?)[-_|]/);
  if (match) {
    return match[1].trim();
  }

  // 尝试从 URL 提取（某些页面可能有企业名称在 URL 中）
  const urlMatch = window.location.href.match(/company_detail_([^/]+)/);
  if (urlMatch) {
    // 这只是 ID，不是名称，返回空
    return '';
  }

  return '';
}

/** 提取结果类型 */
type ExtractedData = Partial<Record<ExtractableField, string>>;

/**
 * 从信息表格提取字段
 */
function extractFromInfoTable(): ExtractedData {
  const result: ExtractedData = {};

  // 查找所有可能的信息容器
  const containers = document.querySelectorAll(
    '.basic-info, .company-info, .info-section, .detail-content'
  );

  // 遍历所有文本节点，查找标签-值对
  const extractFromContainer = (container: Element) => {
    // 方法1：查找 label-value 结构
    const items = container.querySelectorAll(
      '.info-item, .basic-item, .detail-item, tr, dl, .row'
    );

    items.forEach((item) => {
      const labelEl = item.querySelector(
        '.label, .item-label, .info-label, th, dt, .col-label'
      );
      const valueEl = item.querySelector(
        '.value, .item-value, .info-value, td, dd, .col-value'
      );

      if (labelEl && valueEl) {
        const label = getTextContent(labelEl).replace(/[:：]/g, '');
        const value = getTextContent(valueEl);

        const fieldName = FIELD_MAPPING[label];
        if (fieldName && value) {
          result[fieldName] = value;
        }
      }
    });

    // 方法2：查找包含冒号的文本
    const textNodes = container.querySelectorAll('span, div, p, td');
    textNodes.forEach((node) => {
      const text = getTextContent(node);
      const colonMatch = text.match(/^([^:：]+)[:：]\s*(.+)$/);
      if (colonMatch) {
        const [, label, value] = colonMatch;
        const fieldName = FIELD_MAPPING[label.trim()];
        if (fieldName && value && !result[fieldName]) {
          result[fieldName] = value.trim();
        }
      }
    });
  };

  containers.forEach(extractFromContainer);

  // 如果没有找到容器，尝试从整个页面提取
  if (Object.keys(result).length === 0) {
    extractFromContainer(document.body);
  }

  return result;
}

/**
 * 提取统一社会信用代码（特殊处理）
 */
function extractCreditCode(): string {
  // 信用代码格式：18位，包含数字和大写字母
  const creditCodePattern = /[0-9A-Z]{18}/g;

  // 优先从特定元素提取
  const creditElements = document.querySelectorAll(
    '[class*="credit"], [class*="code"], [data-field="creditCode"]'
  );

  for (const el of creditElements) {
    const text = getTextContent(el);
    const match = text.match(creditCodePattern);
    if (match) {
      return match[0];
    }
  }

  // 从页面文本中查找
  const bodyText = document.body.innerText;
  const matches = bodyText.match(creditCodePattern);
  if (matches) {
    // 返回第一个看起来像信用代码的匹配
    for (const match of matches) {
      // 验证格式：第1位为登记管理部门代码，第2位为机构类别代码
      if (/^[1-9][1-9]/.test(match)) {
        return match;
      }
    }
    return matches[0];
  }

  return '';
}

/**
 * 提取完整的企业信息
 */
export function extractEnterpriseData(): EnterpriseImportRequest {
  const companyName = extractCompanyName();
  const tableData = extractFromInfoTable();
  const creditCode = tableData.creditCode || extractCreditCode();

  return {
    companyName: companyName || tableData.companyName || '',
    creditCode: creditCode,
    legalPerson: tableData.legalPerson,
    registeredCapital: tableData.registeredCapital,
    establishmentDate: tableData.establishmentDate,
    address: tableData.address,
    industry: tableData.industry,
    staffSize: tableData.staffSize,
    phone: tableData.phone,
    source: 'chrome_extension',
  };
}

/**
 * 验证提取的数据是否有效
 */
export function validateExtractedData(
  data: EnterpriseImportRequest
): { valid: boolean; errors: string[] } {
  const errors: string[] = [];

  if (!data.companyName) {
    errors.push('未能提取企业名称');
  }

  if (!data.creditCode) {
    errors.push('未能提取统一社会信用代码');
  } else if (!/^[0-9A-Z]{18}$/.test(data.creditCode)) {
    errors.push('统一社会信用代码格式不正确');
  }

  return {
    valid: errors.length === 0,
    errors,
  };
}

/**
 * 等待页面加载完成
 */
export function waitForPageLoad(timeout: number = 10000): Promise<void> {
  return new Promise((resolve) => {
    const startTime = Date.now();

    const checkReady = () => {
      // 检查是否有企业名称元素
      const hasCompanyName = findElement(SELECTORS.companyName) !== null;
      
      // 检查是否有基本信息
      const hasBasicInfo = document.querySelector(
        '.basic-info, .company-info, .info-section'
      ) !== null;

      if (hasCompanyName || hasBasicInfo) {
        resolve();
        return;
      }

      if (Date.now() - startTime > timeout) {
        // 超时但页面可能已加载，继续尝试
        resolve();
        return;
      }

      requestAnimationFrame(checkReady);
    };

    if (document.readyState === 'complete') {
      // 给动态内容一些加载时间
      setTimeout(checkReady, 500);
    } else {
      window.addEventListener('load', () => setTimeout(checkReady, 500));
    }
  });
}
