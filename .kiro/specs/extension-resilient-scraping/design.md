# Design Document: Extension Resilient Scraping

## Overview

本设计文档描述了 Chrome Extension 韧性数据采集系统的架构和实现细节。系统通过配置化、多策略、监控和降级四个核心机制，解决当前硬编码选择器导致的脆弱性问题。

设计目标：
- 将提取逻辑从代码中解耦，支持热更新
- 提供多种提取策略应对页面结构变化
- 自动监测页面变化并提前告警
- 提供友好的降级体验

## Architecture

### 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│              Chrome Extension (Content Script)               │
├─────────────────────────────────────────────────────────────┤
│  ConfigManager (配置管理器)                                  │
│  ├── 从服务器加载配置                                        │
│  ├── 本地缓存（chrome.storage.local）                       │
│  ├── 版本检查和更新                                          │
│  └── 降级到内置配置                                          │
│                                                              │
│  ExtractorEngine (提取引擎)                                  │
│  ├── StrategyExecutor (策略执行器)                          │
│  │   ├── CssStrategy                                         │
│  │   ├── JsonLdStrategy                                      │
│  │   ├── RegexStrategy                                       │
│  │   ├── MetaStrategy                                        │
│  │   └── XPathStrategy                                       │
│  ├── TransformPipeline (数据转换管道)                       │
│  └── ExtractionMonitor (提取监控)                           │
│                                                              │
│  ManualModeUI (手动模式界面)                                 │
│  └── 表单编辑器                                              │
└─────────────────────────────────────────────────────────────┘
                         │
                         ▼ REST API
┌─────────────────────────────────────────────────────────────┐
│                    Backend (Spring Boot)                     │
├─────────────────────────────────────────────────────────────┤
│  ExtractionConfigController                                  │
│  ├── GET /api/config/extraction (获取最新配置)              │
│  ├── POST /api/config/extraction (更新配置)                 │
│  ├── GET /api/config/extraction/history (配置历史)          │
│  └── POST /api/extraction/feedback (提取反馈)               │
│                                                              │
│  ExtractionStatisticsService                                 │
│  ├── 记录策略命中率                                          │
│  ├── 统计提取成功率                                          │
│  └── 生成告警                                                │
└─────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Canary 测试系统 (CI/CD)                         │
├─────────────────────────────────────────────────────────────┤
│  Playwright 测试脚本                                         │
│  ├── 每日自动执行                                            │
│  ├── 测试样本企业页面                                        │
│  ├── 验证提取结果                                            │
│  └── 失败时发送告警                                          │
└─────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### 1. Extraction Config Schema

**职责**: 定义提取规则的数据结构

**JSON Schema**:
```typescript
interface ExtractionConfig {
  version: number;
  timestamp: number;  // Unix timestamp
  platforms: {
    [platformName: string]: PlatformConfig;
  };
}

interface PlatformConfig {
  hostPattern: string;  // 用于匹配 URL
  fields: {
    [fieldName: string]: FieldConfig;
  };
}

interface FieldConfig {
  required: boolean;
  strategies: Strategy[];
}

type Strategy = 
  | CssStrategy 
  | JsonLdStrategy 
  | RegexStrategy 
  | MetaStrategy 
  | XPathStrategy;

interface CssStrategy {
  type: 'css';
  selector: string;
  attribute?: string;  // 默认 'textContent'
  transform?: Transform;
}

interface JsonLdStrategy {
  type: 'json-ld';
  path: string;  // JSONPath 表达式，如 "$.identifier"
  transform?: Transform;
}

interface RegexStrategy {
  type: 'regex';
  pattern: string;
  flags?: string;
  group?: number;  // 捕获组索引，默认 0
}

interface MetaStrategy {
  type: 'meta';
  key: string;  // meta name 或 'title'
  transform?: Transform;
}

interface XPathStrategy {
  type: 'xpath';
  expression: string;
  attribute?: string;
  transform?: Transform;
}

type Transform = 
  | { op: 'regex'; pattern: string; group?: number }
  | { op: 'replace'; search: string; replace: string }
  | { op: 'trim' };
```

**示例配置**:
```json
{
  "version": 1,
  "timestamp": 1703671200000,
  "platforms": {
    "aiqicha": {
      "hostPattern": "aiqicha.baidu.com",
      "fields": {
        "companyName": {
          "required": true,
          "strategies": [
            {
              "type": "meta",
              "key": "title",
              "transform": { "op": "regex", "pattern": "^(.*?)-爱企查", "group": 1 }
            },
            {
              "type": "css",
              "selector": ".company-header h1"
            },
            {
              "type": "css",
              "selector": ".header-content .title"
            }
          ]
        },
        "creditCode": {
          "required": true,
          "strategies": [
            {
              "type": "json-ld",
              "path": "$.identifier"
            },
            {
              "type": "css",
              "selector": "[data-field='creditCode']",
              "attribute": "data-value"
            },
            {
              "type": "regex",
              "pattern": "统一社会信用代码[:：]\\s*([0-9A-Z]{18})",
              "group": 1
            }
          ]
        },
        "legalPerson": {
          "required": false,
          "strategies": [
            {
              "type": "css",
              "selector": ".legal-person",
              "transform": { "op": "replace", "search": "法定代表人：", "replace": "" }
            }
          ]
        }
      }
    }
  }
}
```

### 2. ConfigManager (Extension)

**职责**: 管理配置的加载、缓存和更新

**接口**:
```typescript
class ConfigManager {
  private static readonly CACHE_KEY = 'extraction_config';
  private static readonly CACHE_TTL = 3600000; // 1 hour
  
  /**
   * 获取当前配置（优先使用缓存）
   */
  async getConfig(): Promise<ExtractionConfig>;
  
  /**
   * 从服务器获取最新配置
   */
  async fetchRemoteConfig(): Promise<ExtractionConfig>;
  
  /**
   * 检查配置是否过期
   */
  private isConfigStale(config: ExtractionConfig): boolean;
  
  /**
   * 获取内置默认配置（降级使用）
   */
  private getDefaultConfig(): ExtractionConfig;
}
```

**实现逻辑**:
```typescript
async getConfig(): Promise<ExtractionConfig> {
  // 1. 尝试从缓存加载
  const cached = await chrome.storage.local.get(this.CACHE_KEY);
  if (cached[this.CACHE_KEY]) {
    const config = cached[this.CACHE_KEY] as ExtractionConfig;
    
    // 2. 检查是否过期
    if (!this.isConfigStale(config)) {
      return config;
    }
    
    // 3. 异步更新（不阻塞当前使用）
    this.fetchRemoteConfig().then(newConfig => {
      chrome.storage.local.set({ [this.CACHE_KEY]: newConfig });
    }).catch(err => {
      console.warn('Failed to update config:', err);
    });
    
    return config;
  }
  
  // 4. 缓存不存在，尝试从服务器获取
  try {
    const config = await this.fetchRemoteConfig();
    await chrome.storage.local.set({ [this.CACHE_KEY]: config });
    return config;
  } catch (err) {
    console.error('Failed to fetch remote config:', err);
    // 5. 降级到内置配置
    return this.getDefaultConfig();
  }
}
```

### 3. ExtractorEngine (Extension)

**职责**: 执行提取策略并返回结果

**接口**:
```typescript
class ExtractorEngine {
  constructor(private config: ExtractionConfig) {}
  
  /**
   * 提取所有字段
   */
  async extractAll(): Promise<ExtractionResult>;
  
  /**
   * 提取单个字段
   */
  private async extractField(
    fieldName: string,
    fieldConfig: FieldConfig
  ): Promise<FieldResult>;
  
  /**
   * 执行单个策略
   */
  private async executeStrategy(
    strategy: Strategy
  ): Promise<string | null>;
}

interface ExtractionResult {
  data: Record<string, string>;
  metadata: {
    successCount: number;
    totalCount: number;
    failedFields: string[];
    hitIndexes: Record<string, number>;  // 记录每个字段命中的策略索引
  };
}

interface FieldResult {
  value: string | null;
  hitIndex: number | null;  // 成功策略的索引
}
```

**实现逻辑**:
```typescript
async extractAll(): Promise<ExtractionResult> {
  const platform = this.detectPlatform();
  if (!platform) {
    throw new Error('Unsupported platform');
  }
  
  const platformConfig = this.config.platforms[platform];
  const data: Record<string, string> = {};
  const hitIndexes: Record<string, number> = {};
  const failedFields: string[] = [];
  
  for (const [fieldName, fieldConfig] of Object.entries(platformConfig.fields)) {
    const result = await this.extractField(fieldName, fieldConfig);
    
    if (result.value) {
      data[fieldName] = result.value;
      if (result.hitIndex !== null) {
        hitIndexes[fieldName] = result.hitIndex;
      }
    } else if (fieldConfig.required) {
      failedFields.push(fieldName);
    }
  }
  
  return {
    data,
    metadata: {
      successCount: Object.keys(data).length,
      totalCount: Object.keys(platformConfig.fields).length,
      failedFields,
      hitIndexes,
    },
  };
}

private async extractField(
  fieldName: string,
  fieldConfig: FieldConfig
): Promise<FieldResult> {
  for (let i = 0; i < fieldConfig.strategies.length; i++) {
    const strategy = fieldConfig.strategies[i];
    try {
      const value = await this.executeStrategy(strategy);
      if (value) {
        return { value, hitIndex: i };
      }
    } catch (err) {
      console.warn(`Strategy ${i} failed for ${fieldName}:`, err);
    }
  }
  
  return { value: null, hitIndex: null };
}
```

### 4. Strategy Executors (Extension)

**职责**: 实现各种提取策略

#### CssStrategy
```typescript
class CssStrategyExecutor {
  execute(strategy: CssStrategy): string | null {
    const element = document.querySelector(strategy.selector);
    if (!element) return null;
    
    const value = strategy.attribute 
      ? element.getAttribute(strategy.attribute)
      : element.textContent;
    
    if (!value) return null;
    
    return strategy.transform 
      ? this.applyTransform(value, strategy.transform)
      : value.trim();
  }
}
```

#### JsonLdStrategy
```typescript
class JsonLdStrategyExecutor {
  execute(strategy: JsonLdStrategy): string | null {
    const scripts = document.querySelectorAll('script[type="application/ld+json"]');
    
    for (const script of scripts) {
      try {
        const data = JSON.parse(script.textContent || '');
        const value = this.extractByPath(data, strategy.path);
        
        if (value) {
          return strategy.transform
            ? this.applyTransform(value, strategy.transform)
            : value;
        }
      } catch (err) {
        console.warn('Failed to parse JSON-LD:', err);
      }
    }
    
    return null;
  }
  
  private extractByPath(data: any, path: string): string | null {
    // 简单的 JSONPath 实现（支持 $.field 和 $.field.nested）
    const parts = path.replace(/^\$\./, '').split('.');
    let current = data;
    
    for (const part of parts) {
      if (current && typeof current === 'object' && part in current) {
        current = current[part];
      } else {
        return null;
      }
    }
    
    return typeof current === 'string' ? current : String(current);
  }
}
```

#### RegexStrategy
```typescript
class RegexStrategyExecutor {
  execute(strategy: RegexStrategy): string | null {
    const text = document.body.innerText;
    const regex = new RegExp(strategy.pattern, strategy.flags || '');
    const match = text.match(regex);
    
    if (!match) return null;
    
    const group = strategy.group ?? 0;
    return match[group] || null;
  }
}
```

### 5. ExtractionStatisticsService (Backend)

**职责**: 统计策略命中率并生成告警

**接口**:
```java
@Service
public class ExtractionStatisticsService {
    /**
     * 记录提取结果
     */
    public void recordExtraction(ExtractionFeedback feedback);
    
    /**
     * 获取策略命中率统计
     */
    public Map<String, StrategyStats> getStrategyStats(
        String platform,
        LocalDate startDate,
        LocalDate endDate
    );
    
    /**
     * 检查是否需要告警
     */
    private void checkAndAlert(String platform, String field, int hitIndex);
}

@Data
public class ExtractionFeedback {
    private String platform;
    private Map<String, String> data;
    private Map<String, Integer> hitIndexes;
    private List<String> failedFields;
    private LocalDateTime timestamp;
}

@Data
public class StrategyStats {
    private String field;
    private int strategyIndex;
    private long hitCount;
    private long totalCount;
    private double hitRate;
}
```

**告警逻辑**:
```java
private void checkAndAlert(String platform, String field, int hitIndex) {
    // 获取过去 7 天的统计
    LocalDate endDate = LocalDate.now();
    LocalDate startDate = endDate.minusDays(7);
    
    Map<String, StrategyStats> stats = getStrategyStats(platform, startDate, endDate);
    String key = field + "_" + hitIndex;
    StrategyStats stat = stats.get(key);
    
    if (stat == null) return;
    
    // 如果是高优先级策略（index 0 或 1）且命中率低于 50%
    if (hitIndex <= 1 && stat.getHitRate() < 0.5) {
        alertService.sendAlert(
            "提取策略降级告警",
            String.format("平台 %s 的字段 %s 的策略 %d 命中率降至 %.2f%%",
                platform, field, hitIndex, stat.getHitRate() * 100)
        );
    }
}
```

### 6. Canary Test Script (CI/CD)

**职责**: 自动化监测页面结构变化

**Playwright 脚本**:
```typescript
// scripts/canary-test.ts
import { test, expect } from '@playwright/test';
import { extractEnterpriseData } from '../src/content/extractor';

const SAMPLE_COMPANIES = [
  {
    url: 'https://aiqicha.baidu.com/company_detail_12345',
    expected: {
      companyName: '示例科技有限公司',
      creditCode: '91110000600037341L',
    },
  },
  // 更多样本...
];

test.describe('Extraction Canary Tests', () => {
  for (const sample of SAMPLE_COMPANIES) {
    test(`Extract ${sample.expected.companyName}`, async ({ page }) => {
      // 1. 加载 Cookie（从环境变量）
      const cookies = JSON.parse(process.env.AIQICHA_COOKIES || '[]');
      await page.context().addCookies(cookies);
      
      // 2. 访问页面
      await page.goto(sample.url);
      await page.waitForLoadState('networkidle');
      
      // 3. 执行提取
      const result = await page.evaluate(() => {
        return (window as any).extractEnterpriseData();
      });
      
      // 4. 验证结果
      expect(result.companyName).toBe(sample.expected.companyName);
      expect(result.creditCode).toBe(sample.expected.creditCode);
    });
  }
});
```

**CI/CD 配置** (GitHub Actions):
```yaml
# .github/workflows/canary-test.yml
name: Extraction Canary Test

on:
  schedule:
    - cron: '0 2 * * *'  # 每天凌晨 2 点
  workflow_dispatch:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
      - run: npm ci
      - run: npx playwright install
      - name: Run Canary Tests
        env:
          AIQICHA_COOKIES: ${{ secrets.AIQICHA_COOKIES }}
        run: npm run test:canary
      - name: Send Alert on Failure
        if: failure()
        uses: slackapi/slack-github-action@v1
        with:
          webhook-url: ${{ secrets.SLACK_WEBHOOK }}
          payload: |
            {
              "text": "⚠️ Extraction Canary Test Failed! Page structure may have changed."
            }
```

## Correctness Properties

### Property 1: 配置降级安全性
*For any* 配置加载失败场景，系统应该降级到内置默认配置，而不是崩溃
**Validates: Requirements 1.5**

### Property 2: 策略顺序执行
*For any* 字段配置，策略应该按数组顺序依次执行，直到成功或全部失败
**Validates: Requirements 2.6**

### Property 3: Hit Index 准确性
*For any* 成功提取的字段，记录的 Hit_Index 应该等于成功策略在数组中的索引
**Validates: Requirements 2.7, 5.1**

### Property 4: Transform 幂等性
*For any* Transform 操作，对同一输入执行两次应该产生相同结果
**Validates: Requirements 3.1, 3.2, 3.3**

### Property 5: Required Field 验证
*For any* Required_Field 提取失败，系统应该进入 Manual_Mode 而不是静默导入
**Validates: Requirements 7.1**

### Property 6: 配置缓存一致性
*For any* 缓存的配置，其内容应该与最后一次成功获取的远程配置完全一致
**Validates: Requirements 4.4**

### Property 7: 数据清洗安全性
*For any* 提取的数据，应该经过 HTML 转义且长度不超过 1000 字符
**Validates: Requirements 10.3, 10.4**

### Property 8: 策略命中率统计准确性
*For any* 时间范围内的统计，命中率应该等于 hitCount / totalCount
**Validates: Requirements 5.3**

## Error Handling

### 1. 配置加载失败
```typescript
async getConfig(): Promise<ExtractionConfig> {
  try {
    return await this.fetchRemoteConfig();
  } catch (err) {
    console.error('Failed to fetch config, using default:', err);
    // 降级到内置配置
    return DEFAULT_CONFIG;
  }
}
```

### 2. 策略执行异常
```typescript
private async executeStrategy(strategy: Strategy): Promise<string | null> {
  try {
    switch (strategy.type) {
      case 'css':
        return this.cssExecutor.execute(strategy);
      // ...
    }
  } catch (err) {
    console.warn('Strategy execution failed:', err);
    return null;  // 静默失败，尝试下一个策略
  }
}
```

### 3. Required Field 缺失
```typescript
if (result.metadata.failedFields.length > 0) {
  // 检查是否有必填字段失败
  const hasRequiredFieldFailure = result.metadata.failedFields.some(field => {
    return platformConfig.fields[field].required;
  });
  
  if (hasRequiredFieldFailure) {
    // 打开手动模式
    chrome.runtime.sendMessage({
      type: 'OPEN_MANUAL_MODE',
      data: result.data,
      failedFields: result.metadata.failedFields,
    });
    return;
  }
}
```

### 4. Canary 测试失败
```typescript
test.afterEach(async ({ page }, testInfo) => {
  if (testInfo.status === 'failed') {
    // 截图保存
    await page.screenshot({ 
      path: `screenshots/${testInfo.title}.png` 
    });
    
    // 发送告警
    await sendSlackAlert({
      text: `⚠️ Canary Test Failed: ${testInfo.title}`,
      screenshot: `screenshots/${testInfo.title}.png`,
    });
  }
});
```

## Testing Strategy

### 单元测试

#### 1. ConfigManager 测试
```typescript
describe('ConfigManager', () => {
  it('should use cached config if not stale', async () => {
    const manager = new ConfigManager();
    const config = { version: 1, timestamp: Date.now() };
    await chrome.storage.local.set({ extraction_config: config });
    
    const result = await manager.getConfig();
    expect(result).toEqual(config);
  });
  
  it('should fallback to default config on fetch failure', async () => {
    const manager = new ConfigManager();
    // Mock fetch to fail
    global.fetch = jest.fn().mockRejectedValue(new Error('Network error'));
    
    const result = await manager.getConfig();
    expect(result).toEqual(DEFAULT_CONFIG);
  });
});
```

#### 2. Strategy Executor 测试
```typescript
describe('CssStrategyExecutor', () => {
  it('should extract text content', () => {
    document.body.innerHTML = '<div class="test">Hello</div>';
    const executor = new CssStrategyExecutor();
    
    const result = executor.execute({
      type: 'css',
      selector: '.test',
    });
    
    expect(result).toBe('Hello');
  });
  
  it('should apply transform', () => {
    document.body.innerHTML = '<div class="test">法定代表人：张三</div>';
    const executor = new CssStrategyExecutor();
    
    const result = executor.execute({
      type: 'css',
      selector: '.test',
      transform: { op: 'replace', search: '法定代表人：', replace: '' },
    });
    
    expect(result).toBe('张三');
  });
});
```

### 属性测试

#### 1. Transform 幂等性测试
```typescript
test('Property: Transform operations are idempotent', async () => {
  await fc.assert(
    fc.asyncProperty(
      fc.string(),
      async (input) => {
        const transform: Transform = { op: 'trim' };
        
        const result1 = applyTransform(input, transform);
        const result2 = applyTransform(result1, transform);
        
        expect(result1).toBe(result2);
      }
    ),
    { numRuns: 100 }
  );
});
```

#### 2. Hit Index 准确性测试
```typescript
test('Property: Hit index matches successful strategy index', async () => {
  await fc.assert(
    fc.asyncProperty(
      fc.integer({ min: 0, max: 5 }),
      async (successIndex) => {
        // 创建配置，只有 successIndex 位置的策略会成功
        const strategies = Array(6).fill(null).map((_, i) => ({
          type: 'css',
          selector: i === successIndex ? '.exists' : '.not-exists',
        }));
        
        document.body.innerHTML = '<div class="exists">Test</div>';
        
        const result = await extractField('test', { required: true, strategies });
        
        expect(result.hitIndex).toBe(successIndex);
      }
    ),
    { numRuns: 100 }
  );
});
```

### 集成测试

#### 1. 端到端提取测试
```typescript
test('E2E: Extract from real page HTML', async () => {
  // 加载真实页面的 HTML 快照
  const html = fs.readFileSync('test/fixtures/aiqicha-sample.html', 'utf-8');
  document.body.innerHTML = html;
  
  const engine = new ExtractorEngine(TEST_CONFIG);
  const result = await engine.extractAll();
  
  expect(result.data.companyName).toBe('示例科技有限公司');
  expect(result.data.creditCode).toBe('91110000600037341L');
  expect(result.metadata.successCount).toBeGreaterThan(5);
});
```

### 测试配置

所有属性测试应配置为运行至少 **100 次迭代**。
