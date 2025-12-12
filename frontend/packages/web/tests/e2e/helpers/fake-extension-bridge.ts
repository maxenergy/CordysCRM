import type { Page } from '@playwright/test';

/**
 * 企业搜索结果 fixture 类型
 */
export interface EnterpriseFixture {
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

/**
 * Fake Extension Bridge 配置
 */
export interface FakeExtensionConfig {
  /** 搜索结果 */
  searchResults?: EnterpriseFixture[];
  /** 是否模拟扩展不可用 */
  unavailable?: boolean;
  /** 是否模拟需要登录 */
  needLogin?: boolean;
  /** 是否模拟超时 */
  timeout?: boolean;
  /** 模拟延迟（毫秒） */
  delay?: number;
  /** 自定义错误消息 */
  errorMessage?: string;
}

/**
 * 安装 Fake Extension Bridge
 * 在页面中注入脚本，模拟 Chrome 扩展的 postMessage 响应
 */
export async function installFakeExtensionBridge(
  page: Page,
  config: FakeExtensionConfig = {}
): Promise<void> {
  await page.addInitScript((cfg) => {
    // 注入扩展就绪标记
    if (!cfg.unavailable) {
      const meta = document.createElement('meta');
      meta.name = 'aiqicha-extension-ready';
      meta.content = 'true';
      if (document.head) {
        document.head.appendChild(meta);
      } else {
        document.addEventListener('DOMContentLoaded', () => {
          document.head.appendChild(meta);
        });
      }
    }

    // 监听搜索请求
    window.addEventListener('message', (event) => {
      const data = event.data;

      // 处理 ping 请求
      if (data?.type === 'AIQICHA_EXTENSION_PING') {
        if (!cfg.unavailable) {
          window.postMessage({ type: 'AIQICHA_EXTENSION_PONG', available: true }, '*');
        }
        return;
      }

      // 处理搜索请求
      if (data?.type === 'AIQICHA_SEARCH_REQUEST') {
        const { requestId } = data;

        // 模拟超时
        if (cfg.timeout) {
          return; // 不响应
        }

        const respond = () => {
          // 模拟需要登录
          if (cfg.needLogin) {
            window.postMessage({
              type: 'AIQICHA_SEARCH_RESPONSE',
              requestId,
              success: false,
              message: '请先登录爱企查',
            }, '*');
            return;
          }

          // 模拟自定义错误
          if (cfg.errorMessage) {
            window.postMessage({
              type: 'AIQICHA_SEARCH_RESPONSE',
              requestId,
              success: false,
              message: cfg.errorMessage,
            }, '*');
            return;
          }

          // 返回搜索结果
          window.postMessage({
            type: 'AIQICHA_SEARCH_RESPONSE',
            requestId,
            success: true,
            items: cfg.searchResults || [],
            total: cfg.searchResults?.length || 0,
          }, '*');
        };

        // 模拟延迟
        if (cfg.delay && cfg.delay > 0) {
          setTimeout(respond, cfg.delay);
        } else {
          respond();
        }
      }
    });

    console.log('[Fake Extension Bridge] Installed with config:', cfg);
  }, config);
}

/**
 * 预定义的测试 fixtures
 */
export const fixtures = {
  /** 成功的搜索结果 */
  successResult: [
    {
      pid: 'E2E_TEST_001',
      name: 'E2E测试企业_腾讯科技',
      creditCode: '91440300MA5ETEST01',
      legalPerson: '测试法人',
      address: '深圳市南山区测试路100号',
      status: '存续',
      establishDate: '2020-01-01',
      registeredCapital: '1000万人民币',
      industry: '软件和信息技术服务业',
    },
  ] as EnterpriseFixture[],

  /** 多条搜索结果 */
  multipleResults: [
    {
      pid: 'E2E_TEST_001',
      name: 'E2E测试企业_腾讯科技',
      creditCode: '91440300MA5ETEST01',
      legalPerson: '测试法人A',
      address: '深圳市南山区',
      status: '存续',
    },
    {
      pid: 'E2E_TEST_002',
      name: 'E2E测试企业_阿里巴巴',
      creditCode: '91440300MA5ETEST02',
      legalPerson: '测试法人B',
      address: '杭州市余杭区',
      status: '存续',
    },
  ] as EnterpriseFixture[],

  /** 空结果 */
  emptyResult: [] as EnterpriseFixture[],

  /** 缺少必填字段的结果 */
  missingFieldsResult: [
    {
      pid: 'E2E_TEST_003',
      name: '', // 缺少企业名称
      creditCode: '91440300MA5ETEST03',
    },
  ] as EnterpriseFixture[],
};
