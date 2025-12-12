import { defineConfig, devices } from '@playwright/test';

/**
 * Playwright 配置
 * 用于企业搜索导入的端到端测试
 */
export default defineConfig({
  testDir: './specs',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
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
    {
      name: 'chromium-fake-extension',
      use: { ...devices['Desktop Chrome'] },
      testMatch: /.*\.fake-extension\.spec\.ts/,
    },
    {
      name: 'chromium-real-extension',
      use: {
        ...devices['Desktop Chrome'],
        launchOptions: {
          args: [
            `--disable-extensions-except=${process.env.EXTENSION_PATH || '../chrome-extension/dist'}`,
            `--load-extension=${process.env.EXTENSION_PATH || '../chrome-extension/dist'}`,
          ],
        },
      },
      testMatch: /.*\.real-extension\.spec\.ts/,
    },
  ],
  webServer: {
    command: 'pnpm dev',
    url: 'http://localhost:5173',
    reuseExistingServer: !process.env.CI,
    timeout: 120000,
  },
});
