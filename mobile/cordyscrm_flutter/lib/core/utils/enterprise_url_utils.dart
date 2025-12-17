// 企业信息站点 URL 识别工具
//
// 用于剪贴板检测、分享链接识别、WebView 注入前判断等场景。

/// 企业数据源类型枚举
enum EnterpriseDataSourceType {
  /// 未知数据源
  unknown,

  /// 企查查 (qcc.com)
  qcc,

  /// 爱企查 (aiqicha.baidu.com)
  iqicha,
}

/// 尝试解析 HTTP/HTTPS URL
///
/// 支持以下格式：
/// - 完整 URL: https://www.qcc.com/firm/xxx.html
/// - 无 scheme: www.qcc.com/firm/xxx.html
/// - 协议相对: //www.qcc.com/firm/xxx.html
///
/// 返回 null 如果 URL 无效或不是 HTTP/HTTPS 协议。
Uri? _tryParseHttpUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;

  // 兼容无 scheme 的链接
  final normalized = trimmed.startsWith('//')
      ? 'https:$trimmed'
      : (trimmed.contains('://') ? trimmed : 'https://$trimmed');

  final uri = Uri.tryParse(normalized);
  if (uri == null) return null;

  // 只接受 HTTP/HTTPS 协议
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return null;

  if (uri.host.isEmpty) return null;
  return uri;
}

/// 检测是否为企查查链接
///
/// 返回 true 如果 URL 的 host 包含 qcc.com。
bool isQccLink(String url) {
  final uri = _tryParseHttpUrl(url);
  if (uri == null) return false;
  final host = uri.host.toLowerCase();
  return host == 'qcc.com' || host == 'www.qcc.com' || host.endsWith('.qcc.com');
}


/// 检测是否为企查查企业详情页
///
/// 企查查详情页 URL 格式：
/// - `https://www.qcc.com/firm/{id}.html`
/// - `https://www.qcc.com/company/{id}.html`
///
/// 排除登录、注册等页面。
bool isQccDetailPage(String url) {
  final uri = _tryParseHttpUrl(url);
  if (uri == null) return false;
  if (!isQccLink(url)) return false;

  final path = uri.path.toLowerCase();

  // 排除登录/账号相关页面，避免误注入
  if (path.contains('login') ||
      path.contains('user_login') ||
      path.contains('passport') ||
      path.contains('register')) {
    return false;
  }

  // 企查查详情页格式：/firm/<id>.html 或 /company/<id>.html
  final isFirmPage = path.startsWith('/firm/') && path.endsWith('.html');
  final isCompanyPage = path.startsWith('/company/') && path.endsWith('.html');
  return isFirmPage || isCompanyPage;
}

/// 检测是否为爱企查链接
///
/// 返回 true 如果 URL 的 host 包含 aiqicha.baidu.com。
bool isAiqichaLink(String url) {
  final uri = _tryParseHttpUrl(url);
  if (uri == null) return false;
  final host = uri.host.toLowerCase();
  return host == 'aiqicha.baidu.com' || host.endsWith('.aiqicha.baidu.com');
}

/// 检测是否为爱企查企业详情页
///
/// 爱企查详情页 URL 格式：
/// - `https://aiqicha.baidu.com/company_detail_{id}`
/// - `https://aiqicha.baidu.com/detail?pid={id}`
/// - 其他包含 pid 参数的页面
bool isAiqichaDetailPage(String url) {
  final uri = _tryParseHttpUrl(url);
  if (uri == null) return false;
  if (!isAiqichaLink(url)) return false;

  final path = uri.path;
  final hasPid = uri.queryParameters['pid']?.isNotEmpty == true;
  return path.contains('company_detail') || path.contains('/detail') || hasPid;
}

/// 根据 URL 自动检测数据源类型
///
/// 返回 [EnterpriseDataSourceType.qcc] 如果是企查查链接，
/// 返回 [EnterpriseDataSourceType.iqicha] 如果是爱企查链接，
/// 否则返回 [EnterpriseDataSourceType.unknown]。
EnterpriseDataSourceType detectDataSourceFromUrl(String url) {
  if (isQccLink(url)) return EnterpriseDataSourceType.qcc;
  if (isAiqichaLink(url)) return EnterpriseDataSourceType.iqicha;
  return EnterpriseDataSourceType.unknown;
}
