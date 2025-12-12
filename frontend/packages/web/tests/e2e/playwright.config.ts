import { defineConfig, devices } from '@playwright/test';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

/**
 * Playwright 配置
 * 用于企业搜索导入的端到端测试
 */

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const STORAGE_STATE_PATH = path.resolve(__dirname, '.auth/storageState.json');

export default defineConfig({
  testDir: '.',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  timeout: 60000,
  reporter: [
    ['html', { outputFolder: 'playwright-report' }],
    ['json', { outputFile: 'test-results.json' }],
  ],
  use: {
    baseURL: process.env.CRM_BASE_URL || 'http://localhost:5173',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    // 认证 setup project - 只运行一次登录
    {
      name: 'setup',
      testMatch: /auth\.setup\.ts/,
      timeout: 120000, // 2 分钟超时
    },
    // 使用 fake extension 的测试（主要回归测试）- 需要登录
    {
      name: 'chromium-fake-extension',
      dependencies: ['setup'],
      use: {
        ...devices['Desktop Chrome'],
        storageState: STORAGE_STATE_PATH,
      },
      testMatch: /.*\.fake-extension\.spec\.ts/,
      testDir: './specs',
    },
    // 使用真实扩展的测试（冒烟测试）- 需要登录
    {
      name: 'chromium-real-extension',
      dependencies: ['setup'],
      use: {
        ...devices['Desktop Chrome'],
        storageState: STORAGE_STATE_PATH,
        launchOptions: {
          args: [
            `--disable-extensions-except=${process.env.EXTENSION_PATH || '../chrome-extension/dist'}`,
            `--load-extension=${process.env.EXTENSION_PATH || '../chrome-extension/dist'}`,
          ],
        },
      },
      testMatch: /.*\.real-extension\.spec\.ts/,
      testDir: './specs',
    },
    // 无需登录的测试（用于开发调试）
    {
      name: 'chromium-no-auth',
      use: { ...devices['Desktop Chrome'] },
      testMatch: /.*\.no-auth\.spec\.ts/,
      testDir: './specs',
    },
  ],
  webServer: {
    command: 'pnpm dev',
    url: 'http://localhost:5173',
    reuseExistingServer: !process.env.CI,
    timeout: 120000,
  },
});
