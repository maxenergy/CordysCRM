# Implementation Plan

- [x] 1. 创建数据源抽象层
  - [x] 1.1 创建 `lib/domain/datasources/enterprise_data_source.dart` 定义数据源接口
    - 定义 `EnterpriseDataSourceInterface` 抽象类
    - 包含 `startUrl`、`isDetailPage()`、`isSourceLink()`、`extractDataJs`、`injectButtonJs`、`sourceId` 等成员
    - _Requirements: 5.1, 5.2, 5.3_
  - [x] 1.2 创建 `lib/data/datasources/qcc_data_source.dart` 实现企查查数据源
    - 实现 `QccDataSource` 类
    - 设置 `startUrl` 为 `https://www.qcc.com`
    - 实现企查查特定的 URL 检测和 JS 注入逻辑
    - _Requirements: 1.2, 1.4, 2.1-2.7_
  - [x] 1.3 创建 `lib/data/datasources/aiqicha_data_source.dart` 实现爱企查数据源
    - 实现 `AiqichaDataSource` 类
    - 复用现有的爱企查 JS 注入逻辑
    - _Requirements: 5.3_

- [x] 2. 创建 URL 工具函数
  - [x] 2.1 在 `lib/core/utils/` 目录创建 `enterprise_url_utils.dart`
    - 实现 `isQccDetailPage(String url)` 函数
    - 实现 `isQccLink(String url)` 函数
    - 实现 `isAiqichaDetailPage(String url)` 函数
    - 实现 `isAiqichaLink(String url)` 函数
    - 实现 `detectDataSourceFromUrl(String url)` 函数
    - _Requirements: 1.4, 4.1, 4.2, 5.2, 5.3_
  - [ ]* 2.2 编写属性测试验证 QCC URL 检测逻辑
    - **Property 1: QCC Detail Page URL Detection**
    - **Property 2: QCC Link Detection**
    - **Validates: Requirements 1.4, 4.1, 4.2**
  - [ ]* 2.3 编写属性测试验证爱企查 URL 检测逻辑
    - **Property 3: Aiqicha Detail Page URL Detection**
    - **Property 4: Aiqicha Link Detection**
    - **Validates: Requirements 5.3**
  - [ ]* 2.4 编写属性测试验证数据源自动检测
    - **Property 5: Data Source Auto Detection**
    - **Validates: Requirements 4.1, 4.2**
  - [ ]* 2.5 编写属性测试验证 URL 检测互斥性和蕴含关系
    - **Property 7: URL Detection Mutual Exclusivity**
    - **Property 8: Detail Page Implies Source Link**
    - **Validates: Requirements 5.2, 5.3, 1.4, 4.2**

- [x] 3. 更新 Provider 层支持数据源切换
  - [x] 3.1 在 `enterprise_provider.dart` 中添加数据源配置
    - 定义 `EnterpriseDataSourceType` 枚举（`qcc` 和 `aiqicha`）
    - 创建 `enterpriseDataSourceTypeProvider` 状态管理
    - 创建 `enterpriseDataSourceProvider` 返回当前数据源实例
    - 默认值设置为 `qcc`
    - _Requirements: 5.1, 5.4_
  - [ ]* 3.2 编写属性测试验证数据源配置一致性
    - **Property 6: Data Source Configuration Consistency**
    - **Validates: Requirements 5.2, 5.3, 5.4**

- [x] 4. Checkpoint - 确保所有测试通过
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. 重构 WebView 页面支持多数据源
  - [x] 5.1 重构 `enterprise_webview_page.dart` 使用数据源接口
    - 从 `enterpriseDataSourceProvider` 获取当前数据源
    - 使用数据源的 `startUrl` 作为初始 URL
    - 使用数据源的 `isDetailPage()` 判断是否注入按钮
    - 使用数据源的 `extractDataJs` 和 `injectButtonJs`
    - _Requirements: 1.2, 1.3, 1.4, 1.5, 5.2, 5.3_
  - [x] 5.2 更新 WebView 页面标题显示当前数据源名称
    - 企查查显示"企查查"，爱企查显示"爱企查"
    - _Requirements: 5.2, 5.3_

- [x] 6. 更新路由配置
  - [x] 6.1 在 `app_router.dart` 中更新企业 WebView 路由
    - 支持 `initialUrl` 参数用于分享链接
    - 支持 `dataSource` 参数指定数据源类型
    - _Requirements: 1.2, 4.1_

- [x] 7. 更新企业搜索页面
  - [x] 7.1 修改 `enterprise_search_page.dart` 支持数据源切换
    - 根据 `enterpriseDataSourceTypeProvider` 决定打开哪个数据源的 WebView
    - 更新右上角按钮图标和提示文字
    - _Requirements: 5.2, 5.3_
  - [x] 7.2 更新剪贴板检测逻辑
    - 使用 `detectDataSourceFromUrl` 自动检测链接类型
    - 根据链接类型自动切换数据源并打开 WebView
    - _Requirements: 4.1_

- [x] 8. 更新分享处理
  - [x] 8.1 修改 `share_handler.dart` 支持企查查链接
    - 使用 `detectDataSourceFromUrl` 检测分享链接类型
    - 根据链接类型设置数据源并路由到 WebView 页面
    - _Requirements: 4.1, 4.2_

- [x] 9. 添加数据源设置 UI
  - [x] 9.1 在设置页面添加数据源选择选项
    - 创建数据源选择下拉菜单或单选按钮
    - 持久化用户选择到本地存储（SharedPreferences）
    - 应用启动时恢复用户选择
    - _Requirements: 5.1_

- [x] 10. Final Checkpoint - 确保所有测试通过
  - Ensure all tests pass, ask the user if questions arise.
