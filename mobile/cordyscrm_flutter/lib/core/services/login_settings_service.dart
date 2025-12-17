import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 登录设置服务
/// 
/// 管理服务器地址、记住密码等登录相关配置
class LoginSettingsService {
  static const _keyServerUrl = 'server_url';
  static const _keyRememberPassword = 'remember_password';
  static const _keyUsername = 'saved_username';
  static const _keyPassword = 'saved_password';
  
  static const _defaultServerUrl = 'http://127.0.0.1:8081';
  
  final FlutterSecureStorage _secureStorage;
  SharedPreferences? _prefs;
  
  LoginSettingsService({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();
  
  /// 初始化
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  /// 获取服务器地址
  String getServerUrl() {
    return _prefs?.getString(_keyServerUrl) ?? _defaultServerUrl;
  }
  
  /// 设置服务器地址
  Future<void> setServerUrl(String url) async {
    await _prefs?.setString(_keyServerUrl, url);
  }
  
  /// 获取是否记住密码
  bool getRememberPassword() {
    return _prefs?.getBool(_keyRememberPassword) ?? false;
  }
  
  /// 设置是否记住密码
  Future<void> setRememberPassword(bool value) async {
    await _prefs?.setBool(_keyRememberPassword, value);
    if (!value) {
      // 如果取消记住密码，清除保存的凭据
      await clearSavedCredentials();
    }
  }
  
  /// 获取保存的用户名
  Future<String?> getSavedUsername() async {
    return await _secureStorage.read(key: _keyUsername);
  }
  
  /// 获取保存的密码
  Future<String?> getSavedPassword() async {
    return await _secureStorage.read(key: _keyPassword);
  }
  
  /// 保存登录凭据
  Future<void> saveCredentials(String username, String password) async {
    await _secureStorage.write(key: _keyUsername, value: username);
    await _secureStorage.write(key: _keyPassword, value: password);
  }
  
  /// 清除保存的凭据
  Future<void> clearSavedCredentials() async {
    await _secureStorage.delete(key: _keyUsername);
    await _secureStorage.delete(key: _keyPassword);
  }
}
