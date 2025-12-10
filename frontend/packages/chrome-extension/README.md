# 爱企查 CRM 助手 Chrome Extension

从爱企查网站一键导入企业信息到 CordysCRM 系统的 Chrome 浏览器扩展。

## 功能特性

- 🔗 配置 CRM 系统连接（地址 + JWT Token）
- ✅ 连接测试功能
- 📥 从爱企查页面提取企业信息
- 🚀 一键导入到 CRM 系统

## 开发环境

### 前置要求

- Node.js >= 18
- pnpm >= 8

### 安装依赖

```bash
cd frontend/packages/chrome-extension
pnpm install
```

### 开发模式

```bash
pnpm dev
```

### 构建

```bash
pnpm build
```

构建产物在 `dist` 目录。

## 安装扩展

1. 打开 Chrome 浏览器，访问 `chrome://extensions/`
2. 开启右上角的「开发者模式」
3. 点击「加载已解压的扩展程序」
4. 选择 `dist` 目录

## 使用说明

### 配置 CRM 连接

1. 点击浏览器工具栏中的扩展图标
2. 输入 CRM 系统地址（如 `https://crm.example.com`）
3. 输入 JWT Token（从 CRM 系统获取）
4. 点击「连接测试」验证配置
5. 点击「保存设置」

### 导入企业信息

1. 访问爱企查网站 (https://aiqicha.baidu.com)
2. 搜索并打开企业详情页
3. 点击页面右侧的「导入到 CRM」按钮
4. 确认企业信息后完成导入

## 项目结构

```
chrome-extension/
├── manifest.json          # Chrome Extension 配置
├── package.json           # 项目依赖
├── vite.config.ts         # Vite 构建配置
├── tsconfig.json          # TypeScript 配置
├── public/
│   └── assets/
│       └── icons/         # 扩展图标
└── src/
    ├── types/
    │   └── config.ts      # 类型定义
    ├── utils/
    │   ├── storage.ts     # Chrome Storage 工具
    │   ├── api.ts         # API 请求工具
    │   └── validation.ts  # 表单验证工具
    ├── popup/
    │   ├── popup.html     # Popup 页面
    │   ├── popup.css      # Popup 样式
    │   └── popup.ts       # Popup 逻辑
    ├── content/
    │   ├── content.ts     # Content Script
    │   └── content.css    # Content 样式
    └── background/
        └── background.ts  # Background Service Worker
```

## 技术栈

- TypeScript
- Vite
- Chrome Extension Manifest V3

## 权限说明

- `storage`: 存储 CRM 配置信息
- `activeTab`: 访问当前标签页
- `host_permissions`: 仅在爱企查网站生效

## License

MIT
