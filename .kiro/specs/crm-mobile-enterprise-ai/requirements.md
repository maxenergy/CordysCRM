# Requirements Document

## Introduction

本文档定义了 CordysCRM 系统三个新功能的需求规格：
1. **Flutter 移动端应用** - 开发 Android/iOS 原生应用，将 PC 端全部功能移植到手机端
2. **爱企查企业信息集成** - 通过用户登录后的会话，从爱企查获取企业信息并补全到 CRM 数据库
3. **AI 企业画像与话术生成** - 基于企业信息生成智能画像和外呼话术

## Glossary

- **CRM_System**: CordysCRM 客户关系管理系统
- **Flutter_App**: 使用 Flutter 框架开发的 Android/iOS 原生移动应用
- **Aiqicha_Service**: 爱企查企业信息查询服务
- **Enterprise_Profile**: 企业工商信息档案，包含公司名称、统一社会信用代码、法人、注册资本等
- **Company_Portrait**: AI 生成的企业画像，包含基本信息、商机洞察、风险提示、舆情分析
- **Call_Script**: 外呼话术，为销售人员提供的个性化沟通脚本
- **WebView**: 移动应用内嵌的网页浏览器组件
- **Chrome_Extension**: Chrome 浏览器扩展插件
- **JWT_Token**: JSON Web Token，用于用户身份认证
- **MaxKB**: 集成的智能体开发平台，用于 AI 能力调用

## Requirements

### Requirement 1: Flutter 移动端应用

**User Story:** As a 销售人员, I want to 在手机上使用 CRM 系统的全部功能, so that 我可以随时随地管理客户和跟进商机。

#### Acceptance Criteria

1. WHEN 用户首次打开 Flutter_App THEN CRM_System SHALL 显示登录界面并支持账号密码登录
2. WHEN 用户登录成功 THEN Flutter_App SHALL 展示与 PC 端一致的功能模块（线索、客户、商机、产品、合同）
3. WHEN 用户查看客户列表 THEN Flutter_App SHALL 支持分页加载、搜索筛选和下拉刷新
4. WHEN 用户创建或编辑客户信息 THEN Flutter_App SHALL 提供与 PC 端一致的表单字段和验证规则
5. WHEN 用户添加跟进记录 THEN Flutter_App SHALL 支持文字、图片、语音等多种记录方式
6. WHEN 设备处于离线状态 THEN Flutter_App SHALL 缓存用户相关的客户、线索和跟进记录数据
7. WHEN 设备从离线恢复到在线 THEN Flutter_App SHALL 自动同步本地变更到服务器
8. WHEN 有新的消息或任务提醒 THEN Flutter_App SHALL 通过推送通知及时提醒用户

### Requirement 2: 爱企查企业信息集成 - PC 端

**User Story:** As a 销售人员, I want to 在 PC 端通过浏览器插件从爱企查导入企业信息, so that 我可以快速补全客户的工商信息。

#### Acceptance Criteria

1. WHEN 用户安装 Chrome_Extension 并配置 CRM 地址和 JWT_Token THEN Chrome_Extension SHALL 保存配置到本地存储
2. WHEN 用户在爱企查网站登录并访问企业详情页 THEN Chrome_Extension SHALL 在页面上注入"导入到 CRM"按钮
3. WHEN 用户点击"导入到 CRM"按钮 THEN Chrome_Extension SHALL 从页面 DOM 提取企业名称、统一社会信用代码、法人、注册资本、注册地址等信息
4. WHEN Chrome_Extension 提取到企业信息 THEN Chrome_Extension SHALL 通过 JWT 认证将数据发送到 CRM_System 后端
5. WHEN CRM_System 接收到企业信息 THEN CRM_System SHALL 检查是否存在重复记录（基于统一社会信用代码）
6. WHEN 企业信息与现有客户存在冲突 THEN CRM_System SHALL 返回冲突字段列表供用户选择处理方式
7. WHEN 导入成功 THEN Chrome_Extension SHALL 在页面上显示成功提示

### Requirement 3: 爱企查企业信息集成 - 手机端

**User Story:** As a 销售人员, I want to 在手机端通过 WebView 从爱企查导入企业信息, so that 我可以在移动办公时快速补全客户信息。

#### Acceptance Criteria

1. WHEN 用户在 Flutter_App 中点击"企业信息查询"入口 THEN Flutter_App SHALL 打开内嵌 WebView 加载爱企查网站
2. WHEN 用户在 WebView 中登录爱企查 THEN Flutter_App SHALL 保存登录会话以便后续使用
3. WHEN 用户在 WebView 中浏览企业详情页 THEN Flutter_App SHALL 通过 JavaScript 注入在页面上显示"导入到 CRM"浮动按钮
4. WHEN 用户点击浮动按钮 THEN Flutter_App SHALL 通过 JavaScript 从页面 DOM 提取企业信息
5. WHEN 企业信息提取成功 THEN Flutter_App SHALL 显示数据预览界面供用户确认
6. WHEN 用户确认导入 THEN Flutter_App SHALL 将企业信息保存到 CRM_System 并关联到当前客户或创建新客户
7. WHEN WebView 检测到登录会话失效 THEN Flutter_App SHALL 提示用户重新登录爱企查
8. WHEN 爱企查页面触发验证码 THEN Flutter_App SHALL 允许用户在 WebView 中手动完成验证

### Requirement 4: 爱企查企业信息集成 - 备选方案

**User Story:** As a 销售人员, I want to 通过复制企业名称或分享链接的方式导入企业信息, so that 我有多种方式获取企业工商信息。

#### Acceptance Criteria

1. WHEN 用户复制包含企业名称的文本到剪贴板 THEN Flutter_App SHALL 检测并提示"检测到企业信息，是否搜索？"
2. WHEN 用户从其他应用分享爱企查链接到 Flutter_App THEN Flutter_App SHALL 解析链接中的企业标识
3. WHEN 用户在 Flutter_App 中手动输入企业名称（≥2 个字符）THEN CRM_System SHALL 调用后端搜索接口返回候选企业列表
4. WHEN 后端搜索企业信息 THEN CRM_System SHALL 使用管理员配置的 Aiqicha_Service 凭证进行查询
5. WHEN 管理员配置的凭证失效 THEN CRM_System SHALL 发送告警通知并提示用户联系管理员

### Requirement 5: AI 企业画像生成

**User Story:** As a 销售人员, I want to 查看 AI 生成的企业画像, so that 我可以快速了解客户的全貌和潜在商机。

#### Acceptance Criteria

1. WHEN 用户查看客户详情页 THEN CRM_System SHALL 在页面上展示"AI 企业画像"卡片
2. WHEN 客户已有 Company_Portrait 数据 THEN CRM_System SHALL 分类展示基本信息、商机洞察、风险提示、相关舆情
3. WHEN 客户没有 Company_Portrait 数据 THEN CRM_System SHALL 显示"生成画像"按钮
4. WHEN 用户点击"生成画像"或"刷新画像"按钮 THEN CRM_System SHALL 调用 AI 服务生成企业画像
5. WHEN AI 服务生成画像 THEN CRM_System SHALL 基于 Enterprise_Profile 数据通过 MaxKB 智能体调用 LLM
6. WHEN 画像生成完成 THEN CRM_System SHALL 将结果存储到数据库并更新页面展示
7. WHEN 画像生成失败 THEN CRM_System SHALL 显示错误提示并允许用户重试
8. WHEN AI 服务调用 THEN CRM_System SHALL 记录调用日志包含模型、Token 消耗、耗时、状态

### Requirement 6: AI 话术生成

**User Story:** As a 外呼人员, I want to 获取针对客户的个性化话术, so that 我可以更有效地与客户沟通。

#### Acceptance Criteria

1. WHEN 用户在客户详情页点击"AI 话术"按钮 THEN CRM_System SHALL 打开话术生成面板
2. WHEN 话术生成面板打开 THEN CRM_System SHALL 提供场景选择（首次接触、产品介绍、邀约会议、跟进回访）
3. WHEN 话术生成面板打开 THEN CRM_System SHALL 提供渠道选择（电话、微信、邮件）
4. WHEN 话术生成面板打开 THEN CRM_System SHALL 提供语气选择（专业、热情、简洁）
5. WHEN 用户选择参数并点击"生成话术"THEN CRM_System SHALL 基于客户画像和选择的参数调用 AI 服务
6. WHEN AI 服务生成话术 THEN CRM_System SHALL 使用行业话术模板作为 Prompt 组件
7. WHEN 话术生成完成 THEN CRM_System SHALL 在可编辑文本框中展示生成结果
8. WHEN 用户编辑话术内容 THEN CRM_System SHALL 允许用户修改并保存为个人模板
9. WHEN 用户点击"复制"按钮 THEN CRM_System SHALL 将话术内容复制到剪贴板
10. WHEN 用户生成多次话术 THEN CRM_System SHALL 保留本次会话的生成历史供用户对比选择

### Requirement 7: 话术模板管理

**User Story:** As a 销售管理者, I want to 管理行业话术模板, so that 团队可以使用标准化的沟通话术。

#### Acceptance Criteria

1. WHEN 管理员访问话术模板管理页面 THEN CRM_System SHALL 展示按行业和场景分类的模板列表
2. WHEN 管理员创建新模板 THEN CRM_System SHALL 提供行业、场景、渠道、语气、内容等字段的编辑表单
3. WHEN 管理员编辑模板内容 THEN CRM_System SHALL 支持定义变量占位符（如 {{公司名称}}、{{产品名称}}）
4. WHEN 管理员保存模板 THEN CRM_System SHALL 验证必填字段并存储到数据库
5. WHEN 管理员启用或禁用模板 THEN CRM_System SHALL 更新模板状态并影响话术生成时的可用模板列表

### Requirement 8: 集成配置管理

**User Story:** As a 系统管理员, I want to 配置第三方服务的连接参数, so that 系统可以正常调用爱企查和 AI 服务。

#### Acceptance Criteria

1. WHEN 管理员访问集成配置页面 THEN CRM_System SHALL 展示爱企查服务和 AI 服务的配置表单
2. WHEN 管理员配置爱企查服务 THEN CRM_System SHALL 提供 Cookie/Session 的加密存储
3. WHEN 管理员配置 AI 服务 THEN CRM_System SHALL 提供 LLM 提供商、模型、API Key、温度参数等配置项
4. WHEN 管理员保存配置 THEN CRM_System SHALL 加密敏感信息并存储到数据库
5. WHEN 第三方服务凭证失效 THEN CRM_System SHALL 发送告警通知到管理员
6. WHEN 管理员配置调用限额 THEN CRM_System SHALL 按用户和全局维度限制 API 调用频率

### Requirement 9: 数据安全与审计

**User Story:** As a 系统管理员, I want to 确保第三方数据获取和 AI 调用的安全合规, so that 系统符合数据安全要求。

#### Acceptance Criteria

1. WHEN 系统存储第三方服务凭证 THEN CRM_System SHALL 使用 AES-256 加密存储
2. WHEN 系统调用爱企查服务 THEN CRM_System SHALL 记录操作日志包含操作人、目标企业、操作类型、时间
3. WHEN 系统调用 AI 服务 THEN CRM_System SHALL 记录调用日志包含模型、Token 消耗、成本、状态
4. WHEN 用户导入企业信息 THEN CRM_System SHALL 记录数据变更历史和来源标识
5. WHEN 系统传输敏感数据 THEN CRM_System SHALL 使用 HTTPS 加密传输
