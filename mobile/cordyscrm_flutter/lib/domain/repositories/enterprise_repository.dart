import '../entities/enterprise.dart';

/// 企业仓库接口
///
/// 定义企业导入和 Cookie 管理功能的抽象接口
abstract class EnterpriseRepository {
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
}
