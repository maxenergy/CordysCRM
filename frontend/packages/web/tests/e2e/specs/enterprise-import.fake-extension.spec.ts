import { test, expect } from '@playwright/test';
import {
  installFakeExtensionBridge,
  fixtures,
  type EnterpriseFixture,
} from '../helpers/fake-extension-bridge';
import { TestApiClient, generateTestCreditCode } from '../helpers/api-client';

/**
 * 企业导入功能 E2E 测试（使用 Fake Extension）
 * 
 * 测试覆盖：
 * 1. 扩展不可用场景
 * 2. 搜索成功场景
 * 3. 搜索无结果场景
 * 4. 导入成功场景
 * 5. 导入失败场景
 * 6. 错误处理场景
 */

test.describe('企业导入功能', () => {
  let apiClient: TestApiClient;
  const createdEnterpriseIds: string[] = [];

  test.beforeAll(async ({ request }) => {
    const baseUrl = process.env.CRM_BASE_URL || 'http://localhost:8081';
    apiClient = new TestApiClient(request, baseUrl);
    
    // 登录获取 token（使用测试账号）
    try {
      await apiClient.login(
        process.env.TEST_USERNAME || 'admin',
        process.env.TEST_PASSWORD || 'admin123'
      );
    } catch (e) {
      console.warn('Login failed, some tests may fail:', e);
    }
  });

  test.afterAll(async () => {
    // 清理测试数据
    for (const id of createdEnterpriseIds) {
      try {
        await apiClient.deleteEnterprise(id);
      } catch (e) {
        console.warn(`Failed to cleanup enterprise ${id}:`, e);
      }
    }
    
    // 尝试批量清理
    try {
      const count = await apiClient.cleanupTestData();
      if (count > 0) {
        console.log(`Cleaned up ${count} test records`);
      }
    } catch (e) {
      // 忽略清理失败
    }
  });

  test.describe('扩展检测', () => {
    test('未安装扩展时显示提示', async ({ page }) => {
      // 不安装 fake extension bridge
      await page.goto('/customer');
      
      // 打开企业导入抽屉
      await page.click('button:has-text("导入企业")');
      
      // 输入搜索关键词
      await page.fill('input[placeholder*="搜索"]', '腾讯');
      await page.click('button:has-text("搜索")');
      
      // 应该显示扩展不可用提示
      await expect(page.locator('text=请安装并启用')).toBeVisible({ timeout: 5000 });
    });

    test('扩展已安装时可以搜索', async ({ page }) => {
      await installFakeExtensionBridge(page, {
        searchResults: fixtures.successResult,
      });
      
      await page.goto('/customer');
      await page.click('button:has-text("导入企业")');
      
      await page.fill('input[placeholder*="搜索"]', '腾讯');
      await page.click('button:has-text("搜索")');
      
      // 应该显示搜索结果
      await expect(page.locator('text=E2E测试企业_腾讯科技')).toBeVisible({ timeout: 5000 });
    });
  });

  test.describe('搜索功能', () => {
    test('搜索返回多条结果', async ({ page }) => {
      await installFakeExtensionBridge(page, {
        searchResults: fixtures.multipleResults,
      });
      
      await page.goto('/customer');
      await page.click('button:has-text("导入企业")');
      
      await page.fill('input[placeholder*="搜索"]', '测试');
      await page.click('button:has-text("搜索")');
      
      // 应该显示多条结果
      await expect(page.locator('.enterprise-item')).toHaveCount(2);
      await expect(page.locator('text=E2E测试企业_腾讯科技')).toBeVisible();
      await expect(page.locator('text=E2E测试企业_阿里巴巴')).toBeVisible();
    });

    test('搜索无结果时显示空状态', async ({ page }) => {
      await installFakeExtensionBridge(page, {
        searchResults: fixtures.emptyResult,
      });
      
      await page.goto('/customer');
      await page.click('button:has-text("导入企业")');
      
      await page.fill('input[placeholder*="搜索"]', '不存在的企业');
      await page.click('button:has-text("搜索")');
      
      // 应该显示无结果提示
      await expect(page.locator('text=未找到')).toBeVisible({ timeout: 5000 });
    });

    test('搜索超时时显示错误', async ({ page }) => {
      await installFakeExtensionBridge(page, {
        timeout: true,
      });
      
      await page.goto('/customer');
      await page.click('button:has-text("导入企业")');
      
      await page.fill('input[placeholder*="搜索"]', '测试');
      await page.click('button:has-text("搜索")');
      
      // 应该显示超时错误
      await expect(page.locator('text=超时')).toBeVisible({ timeout: 20000 });
    });

    test('需要登录时显示提示', async ({ page }) => {
      await installFakeExtensionBridge(page, {
        needLogin: true,
      });
      
      await page.goto('/customer');
      await page.click('button:has-text("导入企业")');
      
      await page.fill('input[placeholder*="搜索"]', '测试');
      await page.click('button:has-text("搜索")');
      
      // 应该显示登录提示
      await expect(page.locator('text=登录')).toBeVisible({ timeout: 5000 });
    });
  });

  test.describe('导入功能', () => {
    test('选择企业后可以导入', async ({ page }) => {
      const testCreditCode = generateTestCreditCode();
      const testEnterprise: EnterpriseFixture = {
        pid: 'E2E_IMPORT_TEST',
        name: `E2E导入测试企业_${Date.now()}`,
        creditCode: testCreditCode,
        legalPerson: '测试法人',
        address: '测试地址',
        status: '存续',
      };

      await installFakeExtensionBridge(page, {
        searchResults: [testEnterprise],
      });
      
      await page.goto('/customer');
      await page.click('button:has-text("导入企业")');
      
      // 搜索
      await page.fill('input[placeholder*="搜索"]', '测试');
      await page.click('button:has-text("搜索")');
      
      // 等待结果并选择
      await page.click(`.enterprise-item:has-text("${testEnterprise.name}")`);
      
      // 验证预览区域显示
      await expect(page.locator('.preview-section')).toBeVisible();
      await expect(page.locator(`text=${testEnterprise.name}`)).toBeVisible();
      
      // 点击导入
      await page.click('button:has-text("导入")');
      
      // 等待导入成功提示
      await expect(page.locator('text=成功')).toBeVisible({ timeout: 10000 });
    });

    test('导入后数据落库验证', async ({ page }) => {
      const testCreditCode = generateTestCreditCode();
      const testEnterprise: EnterpriseFixture = {
        pid: 'E2E_DB_TEST',
        name: `E2E数据库验证企业_${Date.now()}`,
        creditCode: testCreditCode,
        legalPerson: '数据库测试法人',
        address: '数据库测试地址',
        status: '存续',
      };

      await installFakeExtensionBridge(page, {
        searchResults: [testEnterprise],
      });
      
      await page.goto('/customer');
      await page.click('button:has-text("导入企业")');
      
      await page.fill('input[placeholder*="搜索"]', '测试');
      await page.click('button:has-text("搜索")');
      await page.click(`.enterprise-item:has-text("${testEnterprise.name}")`);
      await page.click('button:has-text("导入")');
      
      // 等待导入完成
      await expect(page.locator('text=成功')).toBeVisible({ timeout: 10000 });
      
      // 通过 API 验证数据已落库
      const result = await apiClient.findEnterpriseByCreditCode(testCreditCode);
      expect(result.found).toBe(true);
      expect(result.enterprise?.companyName).toBe(testEnterprise.name);
      
      // 记录 ID 用于清理
      if (result.enterprise?.id) {
        createdEnterpriseIds.push(result.enterprise.id);
      }
    });

    test('重复导入时显示已存在提示', async ({ page }) => {
      const testCreditCode = generateTestCreditCode();
      const testEnterprise: EnterpriseFixture = {
        pid: 'E2E_DUPLICATE_TEST',
        name: `E2E重复导入测试_${Date.now()}`,
        creditCode: testCreditCode,
        legalPerson: '重复测试法人',
        status: '存续',
      };

      await installFakeExtensionBridge(page, {
        searchResults: [testEnterprise],
      });
      
      // 第一次导入
      await page.goto('/customer');
      await page.click('button:has-text("导入企业")');
      await page.fill('input[placeholder*="搜索"]', '测试');
      await page.click('button:has-text("搜索")');
      await page.click(`.enterprise-item:has-text("${testEnterprise.name}")`);
      await page.click('button:has-text("导入")');
      await expect(page.locator('text=成功')).toBeVisible({ timeout: 10000 });
      
      // 关闭抽屉
      await page.click('button:has-text("取消")');
      
      // 第二次导入同一企业
      await page.click('button:has-text("导入企业")');
      await page.fill('input[placeholder*="搜索"]', '测试');
      await page.click('button:has-text("搜索")');
      await page.click(`.enterprise-item:has-text("${testEnterprise.name}")`);
      await page.click('button:has-text("导入")');
      
      // 应该显示已存在或更新提示
      await expect(
        page.locator('text=已存在').or(page.locator('text=更新'))
      ).toBeVisible({ timeout: 10000 });
    });
  });

  test.describe('错误处理', () => {
    test('后端错误时显示错误信息', async ({ page }) => {
      await installFakeExtensionBridge(page, {
        errorMessage: '服务器内部错误',
      });
      
      await page.goto('/customer');
      await page.click('button:has-text("导入企业")');
      
      await page.fill('input[placeholder*="搜索"]', '测试');
      await page.click('button:has-text("搜索")');
      
      // 应该显示错误信息
      await expect(page.locator('text=服务器内部错误')).toBeVisible({ timeout: 5000 });
    });

    test('网络错误时可以重试', async ({ page }) => {
      let callCount = 0;
      
      // 第一次返回错误，第二次返回成功
      await page.addInitScript(() => {
        let count = 0;
        const meta = document.createElement('meta');
        meta.name = 'aiqicha-extension-ready';
        meta.content = 'true';
        document.head?.appendChild(meta);

        window.addEventListener('message', (event) => {
          if (event.data?.type === 'AIQICHA_EXTENSION_PING') {
            window.postMessage({ type: 'AIQICHA_EXTENSION_PONG', available: true }, '*');
            return;
          }
          
          if (event.data?.type === 'AIQICHA_SEARCH_REQUEST') {
            count++;
            const { requestId } = event.data;
            
            if (count === 1) {
              // 第一次返回错误
              window.postMessage({
                type: 'AIQICHA_SEARCH_RESPONSE',
                requestId,
                success: false,
                message: '网络错误，请重试',
              }, '*');
            } else {
              // 第二次返回成功
              window.postMessage({
                type: 'AIQICHA_SEARCH_RESPONSE',
                requestId,
                success: true,
                items: [{
                  pid: 'RETRY_TEST',
                  name: '重试成功企业',
                  creditCode: '91440300RETRY0001X',
                }],
                total: 1,
              }, '*');
            }
          }
        });
      });
      
      await page.goto('/customer');
      await page.click('button:has-text("导入企业")');
      
      await page.fill('input[placeholder*="搜索"]', '测试');
      await page.click('button:has-text("搜索")');
      
      // 第一次应该显示错误
      await expect(page.locator('text=网络错误')).toBeVisible({ timeout: 5000 });
      
      // 点击重试
      await page.click('button:has-text("重试")');
      
      // 第二次应该成功
      await expect(page.locator('text=重试成功企业')).toBeVisible({ timeout: 5000 });
    });
  });
});
