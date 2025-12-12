/**
 * 配置存储属性测试
 * **Feature: crm-mobile-enterprise-ai, Property 5: 配置存储往返一致性**
 * **Validates: Requirements 2.1**
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';
import * as fc from 'fast-check';
import type { CRMConfig } from '../types/config';
import { CONFIG_KEYS } from '../types/config';

// Mock chrome.storage.local
const mockStorage: Record<string, string> = {};

const mockChromeStorage = {
  local: {
    set: vi.fn((items: Record<string, string>, callback?: () => void) => {
      Object.assign(mockStorage, items);
      callback?.();
    }),
    get: vi.fn((keys: string[], callback: (result: Record<string, string>) => void) => {
      const result: Record<string, string> = {};
      keys.forEach((key) => {
        if (mockStorage[key] !== undefined) {
          result[key] = mockStorage[key];
        }
      });
      callback(result);
    }),
    remove: vi.fn((keys: string[], callback?: () => void) => {
      keys.forEach((key) => delete mockStorage[key]);
      callback?.();
    }),
  },
};

const mockRuntime = {
  lastError: null as { message: string } | null,
};

// Setup global chrome mock
vi.stubGlobal('chrome', {
  storage: mockChromeStorage,
  runtime: mockRuntime,
});

// Import after mocking
import { saveConfig, loadConfig, clearConfig } from './storage';

// Simple URL generator that doesn't use fc.webUrl (which can be slow)
const simpleUrlArbitrary = fc.tuple(
  fc.constantFrom('http', 'https'),
  fc.stringOf(fc.constantFrom('a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'), { minLength: 3, maxLength: 20 }),
  fc.constantFrom('.com', '.cn', '.io', '.org', '.net'),
).map(([protocol, domain, tld]) => `${protocol}://${domain}${tld}`);

describe('Chrome Extension Config Storage Property Tests', () => {
  beforeEach(() => {
    // Clear mock storage before each test
    Object.keys(mockStorage).forEach((key) => delete mockStorage[key]);
    mockRuntime.lastError = null;
    vi.clearAllMocks();
  });

  /**
   * Property 5: 配置存储往返一致性
   * For any Chrome Extension 配置（CRM地址、JWT Token），保存后读取应该得到完全相同的值。
   */
  it('should preserve config after save and load (Property 5)', async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.record({
          crmUrl: simpleUrlArbitrary,
          jwtToken: fc.string({ minLength: 10, maxLength: 200 }),
        }),
        async (config: CRMConfig) => {
          // Save config
          await saveConfig(config);

          // Load config
          const loaded = await loadConfig();

          // Verify round-trip consistency
          expect(loaded).not.toBeNull();
          expect(loaded!.crmUrl).toBe(config.crmUrl);
          expect(loaded!.jwtToken).toBe(config.jwtToken);
        }
      ),
      { numRuns: 100 }
    );
  });

  /**
   * Property: 空配置处理
   * 当存储中没有配置时，loadConfig 应该返回 null
   */
  it('should return null when no config is stored', async () => {
    const loaded = await loadConfig();
    expect(loaded).toBeNull();
  });

  /**
   * Property: 清除配置后应该返回 null
   */
  it('should return null after clearing config', async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.record({
          crmUrl: simpleUrlArbitrary,
          jwtToken: fc.string({ minLength: 10, maxLength: 200 }),
        }),
        async (config: CRMConfig) => {
          // Save config
          await saveConfig(config);

          // Clear config
          await clearConfig();

          // Load should return null
          const loaded = await loadConfig();
          expect(loaded).toBeNull();
        }
      ),
      { numRuns: 50 }
    );
  });

  /**
   * Property: 配置覆盖
   * 保存新配置应该覆盖旧配置
   */
  it('should overwrite previous config when saving new config', async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.record({
          crmUrl: simpleUrlArbitrary,
          jwtToken: fc.string({ minLength: 10, maxLength: 200 }),
        }),
        fc.record({
          crmUrl: simpleUrlArbitrary,
          jwtToken: fc.string({ minLength: 10, maxLength: 200 }),
        }),
        async (config1: CRMConfig, config2: CRMConfig) => {
          // Save first config
          await saveConfig(config1);

          // Save second config
          await saveConfig(config2);

          // Load should return second config
          const loaded = await loadConfig();
          expect(loaded).not.toBeNull();
          expect(loaded!.crmUrl).toBe(config2.crmUrl);
          expect(loaded!.jwtToken).toBe(config2.jwtToken);
        }
      ),
      { numRuns: 50 }
    );
  });

  /**
   * Property: 特殊字符处理
   * 配置值中的特殊字符应该被正确保存和读取
   */
  it('should handle special characters in config values', async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.record({
          crmUrl: simpleUrlArbitrary,
          jwtToken: fc.string({ minLength: 10, maxLength: 200 }),
        }),
        async (config: CRMConfig) => {
          await saveConfig(config);
          const loaded = await loadConfig();

          expect(loaded).not.toBeNull();
          expect(loaded!.crmUrl).toBe(config.crmUrl);
          expect(loaded!.jwtToken).toBe(config.jwtToken);
        }
      ),
      { numRuns: 50 }
    );
  });
});
