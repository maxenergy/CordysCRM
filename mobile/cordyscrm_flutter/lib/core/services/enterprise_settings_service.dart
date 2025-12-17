import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/enterprise_url_utils.dart';

/// 企业信息查询设置服务
///
/// 负责持久化和恢复用户的数据源选择偏好。
class EnterpriseSettingsService {
  EnterpriseSettingsService(this._prefs);

  final SharedPreferences _prefs;

  /// SharedPreferences 键名
  static const String _dataSourceKey = 'enterprise_data_source';

  /// 获取保存的数据源类型
  ///
  /// 如果没有保存的值，返回默认值 [EnterpriseDataSourceType.qcc]。
  EnterpriseDataSourceType getDataSourceType() {
    final value = _prefs.getString(_dataSourceKey);
    if (value == null) return EnterpriseDataSourceType.qcc;

    return switch (value) {
      'qcc' => EnterpriseDataSourceType.qcc,
      'iqicha' => EnterpriseDataSourceType.iqicha,
      _ => EnterpriseDataSourceType.qcc,
    };
  }

  /// 保存数据源类型
  Future<bool> setDataSourceType(EnterpriseDataSourceType type) async {
    final value = switch (type) {
      EnterpriseDataSourceType.qcc => 'qcc',
      EnterpriseDataSourceType.iqicha => 'iqicha',
      EnterpriseDataSourceType.unknown => 'qcc',
    };
    return _prefs.setString(_dataSourceKey, value);
  }
}

/// SharedPreferences Provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main.dart');
});

/// 企业设置服务 Provider
final enterpriseSettingsServiceProvider = Provider<EnterpriseSettingsService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return EnterpriseSettingsService(prefs);
});
