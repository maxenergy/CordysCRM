/// 企业信息 Web 数据源抽象接口
///
/// 用于在 WebView 中切换不同站点（如：爱企查、企查查）的：
/// - 入口 URL
/// - 页面识别（详情页/站点链接）
/// - JS 注入（按钮 + 数据提取）
///
/// 实现类应提供特定数据源的 URL 检测逻辑和 JavaScript 注入代码。
abstract class EnterpriseDataSourceInterface {
  const EnterpriseDataSourceInterface();

  /// 数据源唯一标识
  ///
  /// 用于区分不同数据源，建议与 Enterprise.source 字段保持一致。
  /// 例如：'qcc'、'iqicha'
  String get sourceId;

  /// UI 展示名称
  ///
  /// 用于 AppBar 标题、数据源切换菜单等 UI 显示。
  /// 例如：'企查查'、'爱企查'
  String get displayName;

  /// 站点入口 URL
  ///
  /// WebView 初始加载的 URL。
  /// 例如：'https://www.qcc.com'、'https://aiqicha.baidu.com'
  String get startUrl;

  /// 判断 URL 是否为企业详情页
  ///
  /// 用于决定是否在页面加载完成后注入导入按钮脚本。
  /// 返回 true 表示当前页面是企业详情页，应注入脚本。
  bool isDetailPage(String url);

  /// 判断 URL 是否属于该数据源
  ///
  /// 用于识别分享链接、剪贴板链接的来源。
  /// 返回 true 表示该 URL 属于此数据源。
  bool isSourceLink(String url);

  /// 数据提取 JavaScript 代码
  ///
  /// 定义 `window.__extractEnterpriseData()` 函数，
  /// 用于从页面 DOM 中提取企业信息。
  ///
  /// 返回的数据结构应包含：
  /// - id: 企业 ID
  /// - name: 企业名称
  /// - creditCode: 统一社会信用代码
  /// - legalPerson: 法定代表人
  /// - registeredCapital: 注册资本
  /// - establishDate: 成立日期
  /// - status: 经营状态
  /// - address: 注册地址
  /// - industry: 所属行业
  /// - businessScope: 经营范围
  /// - phone: 联系电话
  /// - email: 电子邮箱
  /// - website: 官网
  /// - source: 数据来源标识（与 sourceId 一致）
  String get extractDataJs;

  /// 导入按钮注入 JavaScript 代码
  ///
  /// 创建浮动的"导入CRM"按钮，点击时调用 `window.__extractEnterpriseData()`
  /// 并通过 `window.flutter_inappwebview.callHandler()` 将数据传递给 Flutter。
  String get injectButtonJs;

  /// 搜索执行 JavaScript 代码（可选）
  ///
  /// 定义 `window.__search{SourceId}(keyword)` 函数，
  /// 用于在 WebView 中执行搜索并抓取结果。
  ///
  /// 搜索完成后通过以下回调返回结果：
  /// - 成功：`window.flutter_inappwebview.callHandler('on{SourceId}SearchResult', JSON.stringify(results))`
  /// - 失败：`window.flutter_inappwebview.callHandler('on{SourceId}SearchError', errorMessage)`
  ///
  /// 返回 null 表示该数据源不支持 WebView 内搜索。
  String? get searchJs => null;
}
