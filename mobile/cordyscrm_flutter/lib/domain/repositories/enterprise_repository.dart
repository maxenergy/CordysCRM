import '../entities/enterprise.dart';

/// 企业仓库接口
///
/// 定义企业导入和 Cookie 管理功能的抽象接口
abstract class EnterpriseRepository {
  /// 搜索 CRM 本地数据库
  ///
  /// [keyword] 搜索关键词
  /// [page] 页码（从1开始）
  /// [pageSize] 每页数量
  Future<EnterpriseSearchResult> searchLocal({
    required String keyword,
    int page = 1,
    int pageSize = 10,
  });

  /// 搜索爱企查（使用本地保存的 Cookie）
  ///
  /// [keyword] 搜索关键词
  /// [page] 页码（从1开始）
  /// [pageSize] 每页数量
  Future<EnterpriseSearchResult> searchAiqicha({
    required String keyword,
    int page = 1,
    int pageSize = 10,
  });

  /// 搜索企查查（通过 WebView 执行 JS 搜索）
  ///
  /// 需要 WebView 已打开企查查页面并登录。
  /// [keyword] 搜索关键词
  Future<EnterpriseSearchResult> searchQichacha({
    required String keyword,
  });

  /// 搜索企业（兼容旧接口）
  ///
  /// [keyword] 搜索关键词
  /// [page] 页码（从1开始）
  /// [pageSize] 每页数量
  Future<EnterpriseSearchResult> searchEnterprise({
    required String keyword,
    int page = 1,
    int pageSize = 10,
  });

  /// 导入企业为客户
  ///
  /// [enterprise] 企业信息
  /// [forceOverwrite] 是否强制覆盖（冲突时）
  Future<EnterpriseImportResult> importEnterprise({
    required Enterprise enterprise,
    bool forceOverwrite = false,
  });

  /// 保存爱企查 Cookie
  ///
  /// [cookies] Cookie 键值对
  Future<void> saveCookies(Map<String, String> cookies);

  /// 加载爱企查 Cookie
  ///
  /// 返回保存的 Cookie 键值对
  Future<Map<String, String>> loadCookies();

  /// 清除爱企查 Cookie
  Future<void> clearCookies();

  /// 保存 WebView 的 User-Agent
  ///
  /// [userAgent] WebView 的真实 User-Agent
  Future<void> saveUserAgent(String userAgent);

  /// 加载保存的 User-Agent
  ///
  /// 返回保存的 User-Agent，如果没有则返回 null
  Future<String?> loadUserAgent();
}
