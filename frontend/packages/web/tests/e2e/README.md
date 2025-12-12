# 企业导入 E2E 测试

## 概述

本目录包含企业搜索和导入功能的端到端测试，使用 Playwright 框架。

## 测试架构

```
tests/e2e/
├── playwright.config.ts    # Playwright 配置
├── specs/                  # 测试用例
│   ├── enterprise-import.fake-extension.spec.ts  # 使用 Fake Extension 的主回归测试
│   └── enterprise-import.real-extension.spec.ts  # 使用真实扩展的冒烟测试
├── helpers/                # 测试辅助工具
│   ├── fake-extension-bridge.ts  # Fake Extension 模拟器
│   └── api-client.ts             # API 客户端（数据验证/清理）
├── fixtures/               # 测试数据
│   └── enterprise.json     # 企业数据 fixtures
└── README.md
```

## 测试策略

### 分层测试

1. **Fake Extension 测试（主回归）**
   - 不依赖真实 Chrome 扩展
   - 通过注入脚本模拟扩展响应
   - 稳定、快速、可并发
   - 覆盖 80% 的功能场景

2. **Real Extension 测试（冒烟）**
   - 使用真实 Chrome 扩展
   - 需要爱企查登录状态
   - 数量少，只验证关键路径
   - 建议夜间/准入时运行

### 测试覆盖

| 场景 | Fake Extension | Real Extension |
|------|----------------|----------------|
| 扩展不可用 | ✅ | - |
| 搜索成功 | ✅ | ✅ |
| 搜索无结果 | ✅ | - |
| 搜索超时 | ✅ | - |
| 需要登录 | ✅ | ✅ |
| 导入成功 | ✅ | ✅ |
| 重复导入 | ✅ | - |
| 后端错误 | ✅ | - |
| 数据落库验证 | ✅ | ✅ |

## 运行测试

### 安装依赖

```bash
cd frontend/packages/web
pnpm add -D @playwright/test
npx playwright install chromium
```

### 运行 Fake Extension 测试

```bash
# 运行所有 fake extension 测试
npx playwright test --project=chromium-fake-extension

# 运行特定测试文件
npx playwright test enterprise-import.fake-extension.spec.ts

# 带 UI 运行
npx playwright test --ui
```

### 运行 Real Extension 测试

```bash
# 设置扩展路径
export EXTENSION_PATH=../chrome-extension/dist

# 运行冒烟测试
npx playwright test --project=chromium-real-extension
```

### 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `CRM_BASE_URL` | CRM 前端地址 | `http://localhost:5173` |
| `API_BASE_URL` | 后端 API 地址 | `http://localhost:8081` |
| `EXTENSION_PATH` | Chrome 扩展路径 | `../chrome-extension/dist` |
| `TEST_USERNAME` | 测试账号用户名 | `admin` |
| `TEST_PASSWORD` | 测试账号密码 | `admin123` |

## Fake Extension Bridge

`fake-extension-bridge.ts` 提供了模拟 Chrome 扩展行为的能力：

```typescript
import { installFakeExtensionBridge, fixtures } from '../helpers/fake-extension-bridge';

// 模拟成功搜索
await installFakeExtensionBridge(page, {
  searchResults: fixtures.successResult,
});

// 模拟扩展不可用
await installFakeExtensionBridge(page, {
  unavailable: true,
});

// 模拟需要登录
await installFakeExtensionBridge(page, {
  needLogin: true,
});

// 模拟超时
await installFakeExtensionBridge(page, {
  timeout: true,
});

// 模拟延迟响应
await installFakeExtensionBridge(page, {
  searchResults: fixtures.successResult,
  delay: 2000, // 2秒延迟
});
```

## 数据清理策略

### 测试数据标识

所有测试创建的数据都带有 `source: 'E2E_TEST'` 标记，便于识别和清理。

### 清理方式

1. **自动清理**：每个测试套件结束后自动清理创建的数据
2. **批量清理**：调用 `/api/test/cleanup?source=E2E_TEST` 接口
3. **手动清理**：通过数据库 SQL 清理

```sql
DELETE FROM enterprise WHERE source = 'E2E_TEST';
DELETE FROM customer WHERE company_name LIKE 'E2E%';
```

## 常见问题

### Q: 测试运行很慢？

A: 确保使用 Fake Extension 测试，避免真实网络请求。

### Q: 扩展检测失败？

A: 检查 `aiqicha-extension-ready` meta 标签是否正确注入。

### Q: 数据库验证失败？

A: 确保后端服务正在运行，且测试账号有权限访问 API。

### Q: 真实扩展测试失败？

A: 
1. 确保扩展已构建：`cd chrome-extension && pnpm build`
2. 确保已登录爱企查
3. 检查扩展路径是否正确

## 贡献指南

1. 新增测试用例时，优先使用 Fake Extension
2. 保持测试独立性，不依赖其他测试的执行顺序
3. 使用 `generateTestId()` 生成唯一标识，避免数据冲突
4. 确保测试数据在 teardown 中被清理
