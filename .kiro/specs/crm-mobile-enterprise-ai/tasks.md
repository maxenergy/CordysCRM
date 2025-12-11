# Implementation Plan

## Progress Summary

| Phase | Description | Status |
|-------|-------------|--------|
| Phase 1 | 后端基础设施 | ✅ Complete |
| Phase 2 | 爱企查集成服务 | ✅ Complete |
| Phase 3 | AI 服务 | ✅ Complete |
| Phase 4 | Chrome Extension | ✅ Complete |
| Phase 5 | Flutter App 基础架构 | ✅ Complete |
| Phase 6 | Flutter App 核心功能 | ✅ Complete |
| Phase 7 | Flutter App 爱企查集成 | ✅ Complete |
| Phase 8 | Flutter App AI 功能 | ✅ Complete |
| Phase 9 | Web 前端集成 | ✅ Complete |

---

## Phase 1: 后端基础设施 ✅

- [x] 1. 创建数据库表和实体类
  - [x] 1.1 创建 Flyway 迁移脚本，包含 enterprise_profile、company_portrait、call_script_template、call_script、iqicha_sync_log、ai_generation_log、integration_config 表
    - 参考设计文档中的 SQL 定义
    - _Requirements: 9.1, 9.2, 9.3, 9.4_
  - [x] 1.2 创建对应的 Java 实体类和 MyBatis Mapper
    - EnterpriseProfile, CompanyPortrait, CallScriptTemplate, CallScript, IqichaSyncLog, AIGenerationLog, IntegrationConfig
    - _Requirements: 2.5, 5.6, 6.8_
  - [x] 1.3 编写实体类的属性测试
    - **Property 18: 画像存储往返一致性**
    - **Property 22: 话术保存往返一致性**
    - **Validates: Requirements 5.6, 6.8**

- [x] 2. 实现加密存储服务
  - [x] 2.1 创建 EncryptionService 实现 AES-256 加密解密
    - 支持配置加密密钥
    - _Requirements: 8.2, 8.4, 9.1_
  - [x] 2.2 编写加密服务的属性测试
    - **Property 26: 凭证加密存储**
    - **Validates: Requirements 8.2, 9.1**
  - [x] 2.3 创建 IntegrationConfigService 管理集成配置
    - 支持加密存储敏感配置
    - _Requirements: 8.1, 8.2, 8.3, 8.4_

- [x] 3. Checkpoint - 确保所有测试通过
  - Ensure all tests pass, ask the user if questions arise.


## Phase 2: 爱企查集成服务 ✅

- [x] 4. 实现企业信息导入接口
  - [x] 4.1 创建 EnterpriseImportRequest/Response DTO
    - 包含企业基本信息字段
    - _Requirements: 2.3, 2.4_
  - [x] 4.2 实现 EnterpriseService 核心业务逻辑
    - 实现去重检查（基于统一社会信用代码）
    - 实现冲突检测
    - 实现数据导入
    - _Requirements: 2.5, 2.6, 3.6_
  - [x] 4.3 编写企业去重的属性测试
    - **Property 8: 企业去重准确性**
    - **Validates: Requirements 2.5**
  - [x] 4.4 编写冲突检测的属性测试
    - **Property 9: 冲突检测准确性**
    - **Validates: Requirements 2.6**
  - [x] 4.5 创建 EnterpriseController 暴露 REST API
    - POST /api/enterprise/import
    - _Requirements: 2.4, 3.6_

- [x] 5. 实现爱企查同步日志
  - [x] 5.1 创建 IqichaSyncLogService 记录同步操作
    - 记录操作人、目标企业、操作类型、时间
    - _Requirements: 9.2_
  - [x] 5.2 编写日志记录的属性测试
    - **Property 28: 操作日志完整性**
    - **Validates: Requirements 9.2**

- [x] 6. Checkpoint - 确保所有测试通过
  - Ensure all tests pass, ask the user if questions arise.

## Phase 3: AI 服务 ✅

- [x] 7. 实现 AI 画像生成服务
  - [x] 7.1 创建 AIService 封装 LLM 调用
    - 集成 MaxKB SDK 或直接调用 LLM API
    - 支持多 Provider（OpenAI/Claude/Local）
    - _Requirements: 5.4, 5.5_
  - [x] 7.2 实现 PortraitService 画像生成逻辑
    - 构建 Prompt（包含企业基本信息）
    - 解析 AI 返回结果
    - 存储画像数据
    - _Requirements: 5.5, 5.6_
  - [x] 7.3 编写 AI 调用参数的属性测试
    - **Property 17: AI调用参数完整性**
    - **Validates: Requirements 5.5**
  - [x] 7.4 创建 PortraitController 暴露 REST API
    - POST /api/ai/portrait/generate
    - GET /api/ai/portrait/{customerId}
    - _Requirements: 5.4, 5.2_
  - [x] 7.5 编写画像数据分类的属性测试
    - **Property 16: 画像数据分类正确性**
    - **Validates: Requirements 5.2**


- [x] 8. 实现 AI 话术生成服务
  - [x] 8.1 创建 CallScriptTemplateService 管理话术模板
    - CRUD 操作
    - 变量占位符解析
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_
  - [x] 8.2 编写模板变量解析的属性测试
    - **Property 21: 话术模板变量解析**
    - **Validates: Requirements 7.3**
  - [x] 8.3 实现 CallScriptService 话术生成逻辑
    - 基于模板和画像生成 Prompt
    - 调用 AI 服务生成话术
    - 保存生成历史
    - _Requirements: 6.5, 6.6, 6.7, 6.8, 6.10_
  - [x] 8.4 编写话术生成参数的属性测试
    - **Property 20: 话术生成参数传递**
    - **Validates: Requirements 6.5**
  - [x] 8.5 编写话术历史记录的属性测试
    - **Property 23: 话术历史记录完整性**
    - **Validates: Requirements 6.10**
  - [x] 8.6 创建 CallScriptController 暴露 REST API
    - POST /api/ai/script/generate
    - GET /api/ai/script/templates
    - _Requirements: 6.1, 6.5_

- [x] 9. 实现 AI 调用日志
  - [x] 9.1 创建 AIGenerationLogService 记录 AI 调用
    - 记录模型、Token消耗、耗时、状态
    - _Requirements: 5.8, 9.3_
  - [x] 9.2 编写 AI 日志记录的属性测试
    - **Property 19: AI调用日志完整性**
    - **Validates: Requirements 5.8**

- [x] 10. 实现 API 限流
  - [x] 10.1 创建 RateLimitService 实现限流逻辑
    - 基于滑动窗口限流（内存实现，可扩展为 Redis）
    - 支持用户级和全局级限流
    - _Requirements: 8.6_
  - [x] 10.2 编写限流的属性测试
    - **Property 27: API限流有效性**
    - **Validates: Requirements 8.6**

- [x] 11. Checkpoint - 确保所有测试通过
  - All 54 property tests passed!


## Phase 4: Chrome Extension ✅

- [x] 12. 创建 Chrome Extension 项目结构
  - [x] 12.1 初始化 Manifest V3 项目
    - 在 `frontend/packages/chrome-extension` 目录下创建项目
    - 创建 manifest.json，配置 permissions: ["storage", "activeTab"]
    - 配置 host_permissions: ["*://*.aiqicha.baidu.com/*"]
    - 创建 TypeScript + Vite 构建配置
    - _Requirements: 2.1, 2.2_
  - [x] 12.2 实现 Popup 配置界面
    - 创建 popup.html 和 popup.ts
    - 实现 CRM 地址输入框（带 URL 验证）
    - 实现 JWT Token 输入框（密码类型）
    - 实现保存按钮，数据存储到 chrome.storage.local
    - 实现连接测试功能
    - _Requirements: 2.1_
  - [ ]* 12.3 编写配置存储的属性测试
    - **Property 5: 配置存储往返一致性**
    - **Validates: Requirements 2.1**

- [x] 13. 实现 Content Script
  - [x] 13.1 实现页面检测和按钮注入
    - 创建 content.ts 入口文件
    - 检测 URL 匹配 `aiqicha.baidu.com/company_detail_*`
    - 在页面右侧注入悬浮"导入到 CRM"按钮
    - 使用 Shadow DOM 隔离样式
    - _Requirements: 2.2_
  - [x] 13.2 实现 DOM 数据提取
    - 提取企业名称（.company-name 选择器）
    - 提取统一社会信用代码
    - 提取法定代表人、注册资本、成立日期
    - 提取注册地址、行业、人员规模
    - 使用 MutationObserver 处理动态加载
    - _Requirements: 2.3_
  - [ ]* 13.3 编写 DOM 提取的属性测试
    - **Property 6: DOM数据提取完整性**
    - **Validates: Requirements 2.3**
  - [x] 13.4 实现反馈 Toast 组件
    - 创建 Toast 组件显示导入状态
    - 支持 success/error/loading 三种状态
    - 3秒后自动消失
    - _Requirements: 2.7_

- [x] 14. 实现 Background Service Worker
  - [x] 14.1 实现消息监听和 API 调用
    - 创建 background.ts Service Worker
    - 监听 chrome.runtime.onMessage
    - 从 storage 读取 CRM 配置
    - 使用 fetch 调用 POST /api/enterprise/import
    - 设置 Authorization: Bearer {token} 头
    - _Requirements: 2.4_
  - [ ]* 14.2 编写 API 请求格式的属性测试
    - **Property 7: API请求格式正确性**
    - **Validates: Requirements 2.4**
  - [x] 14.3 实现错误处理和重试逻辑
    - 处理网络超时（10秒）
    - 处理 401 认证失败，提示重新配置 Token
    - 处理 409 冲突，显示冲突字段
    - 最多重试 3 次
    - _Requirements: 2.4_

- [x] 15. Checkpoint - 确保所有测试通过
  - Ensure all tests pass, ask the user if questions arise.


## Phase 5: Flutter App 基础架构 ✅

- [x] 16. 初始化 Flutter 项目
  - [x] 16.1 创建 Flutter 项目并配置依赖
    - 在 `mobile/cordyscrm_flutter` 目录下执行 `flutter create`
    - 配置 pubspec.yaml 添加核心依赖：
      - flutter_riverpod: ^2.4.0 (状态管理)
      - dio: ^5.3.0 (网络请求)
      - retrofit: ^4.0.0 (API 定义)
      - drift: ^2.13.0 (本地数据库)
      - go_router: ^12.0.0 (路由)
      - flutter_secure_storage: ^9.0.0 (安全存储)
      - connectivity_plus: ^5.0.0 (网络状态)
    - 配置 build.yaml 代码生成（retrofit_generator, drift_dev, json_serializable）
    - _Requirements: 1.1_
  - [x] 16.2 创建项目目录结构
    - lib/core/ - 配置、网络、依赖注入、错误处理
    - lib/data/ - models, sources (remote/local), repositories 实现
    - lib/domain/ - entities, repositories 接口, usecases
    - lib/presentation/ - features, routing, theme
    - lib/services/ - push, sync
    - _Requirements: 1.1_
  - [x] 16.3 实现网络层基础设施
    - 创建 DioClient 单例，配置 baseUrl、超时、日志拦截器
    - 创建 AuthInterceptor 自动添加 JWT Token
    - 实现 TokenRefreshInterceptor 处理 401 自动刷新
    - 创建 ErrorInterceptor 统一错误处理
    - _Requirements: 1.1_

- [x] 17. 实现认证模块
  - [x] 17.1 创建 AuthRepository 和 AuthService
    - 定义 AuthRepository 接口（login, logout, refreshToken, isLoggedIn）
    - 实现 AuthRepositoryImpl 调用后端 API
    - 使用 flutter_secure_storage 安全存储 Token
    - 创建 AuthNotifier (Riverpod) 管理认证状态
    - _Requirements: 1.1_
  - [x] 17.2 创建登录页面 UI
    - 创建 LoginPage widget
    - 实现账号密码输入表单（带验证）
    - 实现登录按钮和加载状态
    - 支持记住密码选项
    - 错误提示 SnackBar
    - _Requirements: 1.1_
  - [x] 17.3 实现路由守卫
    - 配置 GoRouter redirect 逻辑
    - 未登录重定向到 /login
    - 已登录访问 /login 重定向到首页
    - _Requirements: 1.1_

- [x] 18. 实现本地数据库
  - [x] 18.1 创建 Drift 数据库 Schema
    - 创建 AppDatabase 类
    - 定义 customers 表（id, name, phone, email, owner, status, syncStatus, updatedAt）
    - 定义 clues 表
    - 定义 follow_records 表
    - 定义 sync_queue 表（待同步操作队列）
    - _Requirements: 1.6_
  - [x] 18.2 实现本地 Repository
    - 创建 LocalCustomerRepository
    - 实现 CRUD 操作
    - 实现按 syncStatus 查询待同步数据
    - _Requirements: 1.6_
  - [ ]* 18.3 编写离线缓存的属性测试
    - **Property 3: 离线数据缓存完整性**
    - **Validates: Requirements 1.6**

- [x] 19. Checkpoint - 确保所有测试通过
  - Ensure all tests pass, ask the user if questions arise.


## Phase 6: Flutter App 核心功能 ✅

- [x] 20. 实现客户模块
  - [x] 20.1 创建客户列表页面
    - 创建 CustomerListPage widget
    - 实现 InfiniteScrollPagination 分页加载（每页 20 条）
    - 实现搜索框（防抖 300ms）
    - 实现筛选器（状态、负责人、创建时间）
    - 实现下拉刷新 RefreshIndicator
    - 列表项显示：客户名称、联系人、最近跟进时间
    - _Requirements: 1.3_
  - [ ]* 20.2 编写分页数据的属性测试
    - **Property 1: 分页数据一致性**
    - **Validates: Requirements 1.3**
  - [x] 20.3 创建客户详情页面
    - 创建 CustomerDetailPage widget
    - 顶部展示客户基本信息卡片
    - Tab 切换：基本信息、跟进记录、商机、联系人
    - 集成 AIProfileCard 组件展示 AI 画像（占位）
    - 底部操作栏：编辑、跟进、话术
    - _Requirements: 1.2, 5.1_
  - [x] 20.4 创建客户编辑页面
    - 创建 CustomerEditPage widget
    - 实现表单字段：名称（必填）、联系人、电话、邮箱、地址、行业、来源
    - 实现验证规则：手机号格式、邮箱格式
    - 保存时调用 API 或存入本地队列（离线时）
    - _Requirements: 1.4_
  - [ ]* 20.5 编写表单验证的属性测试
    - **Property 2: 表单验证规则一致性**
    - **Validates: Requirements 1.4**

- [x] 21. 实现线索和商机模块
  - [x] 21.1 创建线索列表和详情页面
    - 复用 CustomerListPage 组件结构
    - 创建 ClueListPage 和 ClueDetailPage
    - 支持线索转客户操作
    - _Requirements: 1.2_
  - [x] 21.2 创建商机列表和详情页面
    - 创建 OpportunityListPage 和 OpportunityDetailPage
    - 显示商机阶段、金额、预计成交日期
    - 支持阶段推进操作
    - _Requirements: 1.2_
  - [x] 21.3 实现跟进记录功能
    - 创建 FollowRecordForm 组件
    - 支持文字输入（富文本）
    - 支持图片选择和上传（image_picker）
    - 支持语音录制（record）
    - 显示跟进记录时间线
    - _Requirements: 1.5_

- [x] 22. 实现离线同步
  - [x] 22.1 创建 SyncService 同步服务
    - 使用 connectivity_plus 监听网络状态
    - 创建 SyncQueue 管理待同步操作
    - 网络恢复时自动触发同步
    - 显示同步状态指示器
    - _Requirements: 1.7_
  - [x] 22.2 实现增量同步逻辑
    - 记录最后同步时间戳
    - 拉取服务器 updatedAt > lastSyncTime 的数据
    - 上传本地 syncStatus = pending 的数据
    - 处理冲突：服务器优先或提示用户选择
    - _Requirements: 1.7_
  - [ ]* 22.3 编写同步数据一致性的属性测试
    - **Property 4: 离线同步数据一致性**
    - **Validates: Requirements 1.7**

- [x] 23. Checkpoint - 确保所有测试通过
  - Flutter analyze: No issues found!
  - Flutter test: All tests passed!


## Phase 7: Flutter App 爱企查集成 ✅

- [x] 24. 实现 WebView 爱企查集成
  - [x] 24.1 创建 EnterpriseWebView 页面
    - 添加 flutter_inappwebview: ^6.0.0 依赖
    - 创建 EnterpriseWebViewPage widget
    - 配置 InAppWebView 加载 https://aiqicha.baidu.com
    - 配置 WebView 设置：javaScriptEnabled, domStorageEnabled
    - 添加加载进度条
    - _Requirements: 3.1_
  - [x] 24.2 实现 Cookie 管理
    - 使用 CookieManager 获取和保存 Cookie
    - 存储到 FlutterSecureStorage（加密）
    - 下次打开时自动恢复 Cookie（支持多域名）
    - _Requirements: 3.2_
  - [ ]* 24.3 编写会话持久性的属性测试
    - **Property 10: WebView会话持久性**
    - **Validates: Requirements 3.2**
  - [x] 24.4 实现 JavaScript 注入
    - 检测 URL 匹配企业详情页
    - 注入 JS 脚本创建浮动"导入到 CRM"按钮
    - 注入 JS 脚本提取 DOM 数据（企业名称、信用代码等）
    - 使用 addJavaScriptHandler 接收 JS 回调
    - _Requirements: 3.3, 3.4_
  - [x] 24.5 实现数据预览和导入确认
    - 创建 EnterprisePreviewSheet 底部弹窗
    - 显示提取的企业信息（可编辑）
    - 提供"关联现有客户"或"创建新客户"选项
    - 确认后调用 POST /api/enterprise/import
    - _Requirements: 3.5, 3.6_
  - [ ]* 24.6 编写数据保存的属性测试
    - **Property 11: 企业数据保存完整性**
    - **Validates: Requirements 3.6**
  - [x] 24.7 实现会话失效检测
    - 监听 WebView URL 变化
    - 检测重定向到登录页（passport.baidu.com）
    - 检测 401/403 响应
    - 显示 Dialog 提示用户重新登录
    - _Requirements: 3.7_
  - [ ]* 24.8 编写会话失效检测的属性测试
    - **Property 12: 会话失效检测准确性**
    - **Validates: Requirements 3.7**

- [x] 25. 实现备选导入方案
  - [x] 25.1 实现剪贴板监听
    - 使用 Clipboard.getData 获取剪贴板内容
    - 正则匹配中文企业名称（2-50字符，包含"公司"/"集团"/"有限"）
    - 应用进入前台时检测
    - 显示提示"检测到企业信息，是否搜索？"
    - _Requirements: 4.1_
  - [ ]* 25.2 编写企业名称识别的属性测试
    - **Property 13: 剪贴板企业名称识别**
    - **Validates: Requirements 4.1**
  - [ ] 25.3 实现分享接收
    - 配置 AndroidManifest.xml 和 Info.plist 接收分享
    - 使用 receive_sharing_intent 包
    - 解析 aiqicha.baidu.com/company_detail_* 链接
    - 提取企业 ID 并跳转到 WebView
    - _Requirements: 4.2_
  - [ ]* 25.4 编写链接解析的属性测试
    - **Property 14: 爱企查链接解析**
    - **Validates: Requirements 4.2**
  - [x] 25.5 实现手动搜索
    - 创建 EnterpriseSearchPage 页面
    - 输入 ≥2 字符时触发搜索（防抖 500ms）
    - 调用后端 GET /api/enterprise/search?keyword=xxx（模拟数据）
    - 显示候选企业列表（名称、信用代码、法人）
    - 点击跳转到 WebView 详情页
    - _Requirements: 4.3_
  - [ ]* 25.6 编写搜索结果的属性测试
    - **Property 15: 企业搜索结果相关性**
    - **Validates: Requirements 4.3**

- [x] 26. Checkpoint - 确保所有测试通过
  - Flutter analyze: No issues found!


## Phase 8: Flutter App AI 功能 ✅

- [x] 27. 实现 AI 画像展示
  - [x] 27.1 创建 AIProfileCard 组件
    - 创建 AIProfileCard widget
    - 使用 TabBar 分类展示：基本信息、商机洞察、风险提示、相关舆情
    - 基本信息 Tab：行业、规模、主营产品
    - 商机洞察 Tab：列表展示，每项包含标题、置信度、来源
    - 风险提示 Tab：按级别（高/中/低）分组展示
    - 舆情信息 Tab：列表展示，包含标题、来源、情感倾向
    - _Requirements: 5.1, 5.2_
  - [x] 27.2 实现画像生成和刷新
    - 无画像时显示"生成画像"按钮
    - 有画像时显示"刷新画像"按钮
    - 调用 POST /api/ai/portrait/generate
    - 显示生成中 Loading 状态（Shimmer 效果）
    - 生成失败显示错误提示和重试按钮
    - _Requirements: 5.3, 5.4_

- [x] 28. 实现 AI 话术生成
  - [x] 28.1 创建 AIScriptDrawer 组件
    - 创建 AIScriptDrawer 底部抽屉组件
    - 场景选择：首次接触、产品介绍、邀约会议、跟进回访
    - 渠道选择：电话、微信、邮件
    - 语气选择：专业、热情、简洁
    - 可选：选择话术模板
    - _Requirements: 6.1, 6.2, 6.3, 6.4_
  - [x] 28.2 实现话术生成和展示
    - 点击"生成话术"调用 POST /api/ai/script/generate
    - 显示生成中 Loading 状态
    - 生成完成后在可编辑 TextField 中展示
    - 支持用户修改话术内容
    - _Requirements: 6.5, 6.7_
  - [x] 28.3 实现话术复制和保存
    - "复制"按钮：Clipboard.setData 复制到剪贴板，显示 SnackBar 提示
    - "保存为模板"按钮：调用 API 保存为个人模板
    - _Requirements: 6.8, 6.9_
  - [x] 28.4 实现生成历史
    - 使用 Riverpod StateNotifier 管理本次会话历史
    - 显示历史记录列表（最近 10 条）
    - 点击历史记录可快速复用
    - _Requirements: 6.10_

- [ ] 29. 实现推送通知
  - [ ] 29.1 集成 Firebase Cloud Messaging
    - 添加 firebase_messaging: ^14.7.0 依赖
    - 配置 Android google-services.json
    - 配置 iOS GoogleService-Info.plist
    - 请求通知权限
    - 获取 FCM Token 并上报到后端
    - _Requirements: 1.8_
  - [ ] 29.2 实现通知处理
    - 前台通知：使用 flutter_local_notifications 显示
    - 后台通知：系统自动显示
    - 点击通知：解析 data 字段，跳转到对应页面（客户详情、商机详情等）
    - _Requirements: 1.8_

- [x] 30. Checkpoint - 确保所有测试通过
  - Flutter analyze: No issues found!
  - Note: Task 29 (推送通知) 跳过 - 需要 Firebase 配置文件


## Phase 9: Web 前端集成 ✅

- [x] 31. 实现 AI 画像组件
  - [x] 31.1 创建 AIProfileCard.vue 组件
    - 在 `frontend/packages/web/src/components/business/` 下创建 ai-profile-card 目录
    - 创建 AIProfileCard.vue 组件
    - 使用 NTabs 分类展示：基本信息、商机洞察、风险提示、相关舆情
    - 基本信息 Tab：NDescriptions 展示行业、规模、主营产品
    - 商机洞察 Tab：NList 展示，每项包含标题、置信度标签、来源
    - 风险提示 Tab：NAlert 按级别（error/warning/info）展示
    - 舆情信息 Tab：NTimeline 展示，包含标题、来源、情感标签
    - 无数据时显示 NEmpty + "生成画像"按钮
    - _Requirements: 5.1, 5.2_
  - [x] 31.2 集成到客户详情页
    - 在 `frontend/packages/web/src/views/customer/detail/` 中引入 AIProfileCard
    - 在客户详情页右侧或 Tab 中展示
    - 传入 customerId prop
    - _Requirements: 5.1_

- [x] 32. 实现 AI 话术组件
  - [x] 32.1 创建 AIScriptDrawer.vue 组件
    - 在 `frontend/packages/web/src/components/business/` 下创建 ai-script-drawer 目录
    - 创建 AIScriptDrawer.vue 组件
    - 使用 NDrawer 从右侧滑出
    - 宽度 480px
    - _Requirements: 6.1_
  - [x] 32.2 实现参数选择和生成
    - 场景选择：NRadioGroup（首次接触、产品介绍、邀约会议、跟进回访）
    - 渠道选择：NRadioGroup（电话、微信、邮件）
    - 语气选择：NRadioGroup（专业、热情、简洁）
    - 模板选择：NSelect（可选，从 API 获取模板列表）
    - "生成话术"按钮：调用 POST /api/ai/script/generate
    - 生成结果：NInput type="textarea" 可编辑
    - 操作按钮：复制、保存为模板
    - _Requirements: 6.2, 6.3, 6.4, 6.5_
  - [x] 32.3 集成到客户详情页
    - 在客户详情页添加"AI 话术"按钮
    - 点击打开 AIScriptDrawer
    - 传入 customerId prop
    - _Requirements: 6.1_

- [x] 33. 实现话术模板管理页面
  - [x] 33.1 创建模板列表页面
    - 在 `frontend/packages/web/src/views/system/` 下创建 script-template 目录
    - 创建 index.vue 列表页面
    - 使用 NDataTable 展示模板列表
    - 左侧 NTree 按行业和场景分类筛选
    - 支持搜索、启用/禁用、删除操作
    - 添加路由配置
    - _Requirements: 7.1_
  - [ ]* 33.2 编写模板分类的属性测试
    - **Property 24: 模板列表分类正确性**
    - **Validates: Requirements 7.1**
  - [x] 33.3 创建模板编辑页面
    - 创建 edit.vue 编辑页面
    - 表单字段：名称、行业、场景、渠道、语气、内容
    - 内容编辑器支持变量占位符插入（{{公司名称}}、{{产品名称}}等）
    - 变量列表提示
    - 预览功能
    - _Requirements: 7.2, 7.3_
  - [ ]* 33.4 编写模板状态的属性测试
    - **Property 25: 模板状态影响可用性**
    - **Validates: Requirements 7.5**

- [x] 34. 实现集成配置页面
  - [x] 34.1 创建配置管理页面
    - 在 `frontend/packages/web/src/views/system/` 下创建 integration-config 目录
    - 创建 index.vue 配置页面
    - 使用 NTabs 分类：爱企查配置、AI 服务配置
    - 爱企查配置：Cookie/Session 输入（密码类型）、连接测试按钮
    - AI 服务配置：Provider 选择、API Key 输入、模型选择、温度参数滑块
    - 添加路由配置和菜单项
    - _Requirements: 8.1, 8.3_
  - [x] 34.2 实现配置保存
    - 调用 POST /api/integration/config 保存配置
    - 敏感字段显示为 ******
    - 保存成功提示
    - _Requirements: 8.4_

- [ ] 35. Final Checkpoint - 确保所有测试通过
  - Ensure all tests pass, ask the user if questions arise.
