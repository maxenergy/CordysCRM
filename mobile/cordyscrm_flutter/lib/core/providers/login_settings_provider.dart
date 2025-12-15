import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/login_settings_service.dart';

/// 登录设置服务 Provider
final loginSettingsServiceProvider = Provider<LoginSettingsService>((ref) {
  return LoginSettingsService();
});

/// 服务器地址 Provider
final serverUrlProvider = StateProvider<String>((ref) {
  return 'http://192.168.1.226:8081';
});

/// 记住密码 Provider
final rememberPasswordProvider = StateProvider<bool>((ref) {
  return false;
});
