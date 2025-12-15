# CordysCRM 项目档案

## 项目概述

**Cordys CRM** 是新一代的开源 AI CRM 系统，由 [飞致云](https://fit2cloud.com/) 匠心出品。系统集信息化、数字化、智能化于一体，帮助企业实现从线索到回款（L2C）的全流程精细化管理。

> Cordys [/ˈkɔːrdɪs/] 由"Cord"（连接之绳）与"System"（系统）融合而成，寓意"关系的纽带系统"。

## 核心优势

| 特性 | 描述 |
|------|------|
| 灵活易用 | 现代化技术栈，支持企业微信/钉钉/飞书集成 |
| 安全可控 | 私有化部署，数据主权完全自主 |
| AI 加持 | 开放 MCP Server，集成 MaxKB 智能体 |
| BI 加持 | 融合 DataEase 与 SQLBot 数据分析能力 |

## 技术架构

```
┌─────────────────────────────────────────────────────────────────┐
│                         客户端层                                  │
├─────────────┬─────────────┬─────────────┬─────────────────────────┤
│  Web 前端   │  H5 移动端   │ Flutter App │   Chrome Extension     │
│ Vue3+Naive  │ Vue3+Vant   │ Riverpod    │   Manifest V3          │
└─────────────┴─────────────┴─────────────┴─────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         后端服务层                                │
├─────────────────────────────────────────────────────────────────┤
│  Spring Boot 3.5.7 + Java 21 + MyBatis + Shiro                  │
├─────────────┬─────────────┬─────────────┬─────────────────────────┤
│  CRM 核心   │ 爱企查服务   │  AI 服务    │   集成配置服务          │
└─────────────┴─────────────┴─────────────┴─────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         数据存储层                                │
├─────────────────────────────────────────────────────────────────┤
│              MySQL 8.x          │         Redis                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         外部服务                                  │
├─────────────┬─────────────┬─────────────────────────────────────┤
│   MaxKB     │  DataEase   │  LLM Provider (OpenAI/Claude/Local) │
└─────────────┴─────────────┴─────────────────────────────────────┘
```

## 项目结构

```
cordys-crm/
├── backend/                    # 后端服务
│   ├── app/                    # 应用启动模块
│   ├── crm/                    # CRM 核心业务模块
│   │   ├── src/main/java/cn/cordys/
│   │   │   ├── crm/            # CRM 业务代码
│   │   │   │   ├── integration/  # 集成服务（爱企查、AI）
│   │   │   │   └── system/       # 系统管理
│   │   │   ├── common/         # 公共组件
│   │   │   └── config/         # 配置类
│   │   └── src/test/           # 测试代码
│   └── framework/              # 框架层
│
├── frontend/                   # 前端项目
│   └── packages/
│       ├── web/                # PC Web 端 (Vue3 + Naive-UI)
│       ├── mobile/             # H5 移动端 (Vue3 + Vant-UI)
│       ├── lib-shared/         # 共享库
│       └── chrome-extension/   # Chrome 浏览器扩展
│
├── mobile/                     # 原生移动端
│   └── cordyscrm_flutter/      # Flutter App (Android/iOS)
│
├── installer/                  # 安装部署脚本
└── .kiro/specs/                # 功能规格文档
```

## 技术栈详情

### 后端
| 技术 | 版本 | 用途 |
|------|------|------|
| Java | 21 | 运行时 |
| Spring Boot | 3.5.7 | 应用框架 |
| MyBatis | 3.0.5 | ORM |
| Shiro | 2.0.4 | 安全框架 |
| Redisson | 3.52.0 | Redis 客户端 |
| jqwik | - | 属性测试 |

### 前端 (Web/H5)
| 技术 | 版本 | 用途 |
|------|------|------|
| Vue | 3.5.22 | UI 框架 |
| Naive-UI | - | PC 端组件库 |
| Vant-UI | - | 移动端组件库 |
| Pinia | 2.3.0 | 状态管理 |
| Vue Router | 4.5.0 | 路由 |
| TypeScript | 5.9.3 | 类型系统 |

### Flutter App
| 技术 | 版本 | 用途 |
|------|------|------|
| Flutter | 3.x | 跨平台框架 |
| Riverpod | 2.4.0 | 状态管理 |
| Dio | 5.3.0 | 网络请求 |
| Drift | 2.24.0 | 本地数据库 |
| Go Router | 12.0.0 | 路由 |

### Chrome Extension
| 技术 | 用途 |
|------|------|
| Manifest V3 | 扩展规范 |
| TypeScript | 开发语言 |
| Vite | 构建工具 |
| fast-check | 属性测试 |

## 核心功能模块

### 1. CRM 核心功能
- 线索管理（Clue）
- 客户管理（Customer）
- 联系人管理（Contact）
- 商机管理（Opportunity）
- 跟进记录（Follow Record）
- 合同管理（Contract）
- 回款管理（Payment）

### 2. 爱企查企业信息集成
通过 Chrome Extension 和 Flutter WebView 实现企业工商信息导入：

```
数据流（反爬虫绕过架构）:
┌─────────────┐    postMessage    ┌─────────────┐    sendMessage    ┌─────────────┐
│  CRM 前端   │ ───────────────► │Content Script│ ───────────────► │ Background  │
└─────────────┘                   └─────────────┘                   └─────────────┘
                                                                          │
                                                                          │ fetch + credentials
                                                                          ▼
┌─────────────┐    POST /api/     ┌─────────────┐    postMessage    ┌─────────────┐
│  后端存储   │ ◄─────────────── │  CRM 前端   │ ◄─────────────── │ Background  │
└─────────────┘                   └─────────────┘                   └─────────────┘
```

关键技术点：
- 使用 `credentials: 'include'` 自动携带 Cookie
- 使用 `window.postMessage` + Content Script 桥接
- 检测 BDUSS/BAIDUID Cookie 判断登录状态
- 检测验证码重定向 (captcha/wappass)

### 3. AI 企业画像与话术生成
- 企业画像生成（基本信息、商机洞察、风险提示、舆情信息）
- 话术生成（支持场景、渠道、语气选择）
- 话术模板管理
- AI 调用日志记录

## 数据库表结构

### 集成相关表
| 表名 | 描述 |
|------|------|
| enterprise_profile | 企业工商信息 |
| company_portrait | AI 企业画像 |
| call_script_template | 话术模板 |
| call_script | 话术记录 |
| iqicha_sync_log | 爱企查同步日志 |
| ai_generation_log | AI 生成日志 |
| integration_config | 集成配置 |

## API 接口

### 企业信息导入
```
POST /api/enterprise/import
Authorization: Bearer {token}
Content-Type: application/json

{
  "companyName": "企业名称",
  "creditCode": "统一社会信用代码",
  "legalPerson": "法定代表人",
  "registeredCapital": "注册资本",
  "establishmentDate": "成立日期",
  "address": "注册地址",
  "industry": "所属行业",
  "staffSize": "人员规模",
  "source": "chrome_extension|webview|manual"
}
```

### AI 画像生成
```
POST /api/ai/portrait/generate
GET /api/ai/portrait/{customerId}
```

### AI 话术生成
```
POST /api/ai/script/generate
GET /api/ai/script/templates
```

## 测试策略

### 属性测试 (Property-Based Testing)
项目采用属性测试验证系统正确性：

| 层级 | 框架 | 测试数量 |
|------|------|----------|
| 后端 | jqwik | 54+ |
| Flutter | fast_check | 59+ |
| Chrome Extension | fast-check | 15+ |

### 正确性属性示例
- Property 5: 配置存储往返一致性
- Property 8: 企业去重准确性
- Property 9: 冲突检测准确性
- Property 26: 凭证加密存储

## 开发命令

### 后端
```bash
# 编译
mvn compile

# 测试
mvn test -pl backend/crm

# 运行
mvn spring-boot:run -pl backend/app
```

### 前端
```bash
cd frontend

# 安装依赖
pnpm install

# 开发
pnpm -r run dev

# 构建
pnpm -r run build
```

### Flutter
```bash
cd mobile/cordyscrm_flutter

# 分析
flutter analyze

# 测试
flutter test

# 运行
flutter run
```

### Chrome Extension
```bash
cd frontend/packages/chrome-extension

# 开发
pnpm dev

# 构建
pnpm build

# 测试
pnpm test
```

## 部署方式

### Docker 一键部署
```bash
docker run -d \
  --name cordys-crm \
  --restart unless-stopped \
  -p 8081:8081 \
  -p 8082:8082 \
  -v ~/cordys:/opt/cordys \
  1panel/cordys-crm
```

### 访问信息
- 地址: http://<服务器IP>:8081/
- 用户名: `admin`
- 密码: `CordysCRM`

## 版本历史

| 版本 | 日期 | 里程碑 |
|------|------|--------|
| v1.0 | 2025.06 | 开发完成 |
| v1.1.5 | 2025.08.27 | 开始公测 |
| v1.2.0 | 2025.09.19 | 开放 MCP Server |
| v1.3.0 | 2025.11.03 | 代码正式开源 |
| v1.3.5 | 2025.12.04 | 最新版本 |

## 相关项目

- [MaxKB](https://github.com/1Panel-dev/MaxKB) - 企业级智能体平台
- [DataEase](https://github.com/dataease/dataease) - 开源 BI 工具
- [SQLBot](https://github.com/dataease/SQLBot) - 智能问数系统
- [1Panel](https://github.com/1panel-dev/1panel) - Linux 运维管理面板

## 许可证

本项目遵循 [FIT2CLOUD Open Source License](LICENSE)（基于 GPLv3）。

商业授权联系：`support@fit2cloud.com`

---

*文档更新时间: 2025-12-15*
