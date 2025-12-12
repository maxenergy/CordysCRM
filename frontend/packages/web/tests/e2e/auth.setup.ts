import { test as setup, expect } from '@playwright/test';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

/**
 * 认证 Setup
 * 在所有测试运行前执行一次登录，保存登录状态供后续测试复用
 */

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const STORAGE_STATE_PATH = path.resolve(__dirname, '.auth/storageState.json');

setup('authenticate', async ({ page }) => {
  const username = process.env.E2E_USERNAME || 'admin';
  const password = process.env.E2E_PASSWORD || 'CordysCRM';

  // 确保 .auth 目录存在
  await fs.mkdir(path.dirname(STORAGE_STATE_PATH), { recursive: true });

  // 添加调试日志
  page.on('console', (m) => console.log('[browser]', m.type(), m.text()));
  page.on('pageerror', (e) => console.log('[pageerror]', e));
  page.on('requestfailed', (r) => console.log('[requestfailed]', r.url(), r.failure()?.errorText));

  // 访问登录页
  await page.goto('/login');

  // 等待登录表单加载完成（等待 preheat 完成）
  await page.waitForSelector('.login-form .form', { timeout: 15000 });

  // 关键：等待公钥接口返回
  await page.waitForResponse(
    (r) => r.url().includes('/get-key') && r.ok(),
    { timeout: 15000 }
  ).catch(() => {
    console.log('[Auth Setup] /get-key response not captured, may have already loaded');
  });

  // 使用更精确的选择器，避免 .first() 命中错误的 input
  const usernameInput = page.locator('.login-input').locator('input');
  const passwordInput = page.locator('.login-password-input').locator('input[type="password"]');

  // 填写用户名
  await usernameInput.fill(username);
  await expect(usernameInput).toHaveValue(username);

  // 填写密码
  await passwordInput.fill(password);
  await expect(passwordInput).toHaveValue(password);

  // 触发 blur 让表单校验完成
  await passwordInput.press('Tab');

  // 点击登录按钮并等待登录响应
  const [loginResp] = await Promise.all([
    page.waitForResponse((r) => r.url().includes('/login'), { timeout: 30000 }),
    page.getByRole('button', { name: '登录' }).click(),
  ]);

  // 打印登录响应状态（不打印 body 以避免泄露敏感信息）
  console.log('[login]', loginResp.status(), loginResp.url());

  // 检查登录是否成功
  if (!loginResp.ok()) {
    throw new Error(`Login failed with status ${loginResp.status()}: ${responseBody}`);
  }

  // 登录成功后等待页面加载完成
  // 由于登录响应已经是 200，我们只需要等待一小段时间让页面跳转
  await page.waitForTimeout(3000);

  console.log('[Auth Setup] Login response received, saving storage state...');

  // 保存登录状态
  await page.context().storageState({ path: STORAGE_STATE_PATH });

  console.log('[Auth Setup] Login completed, storage state saved');
});
