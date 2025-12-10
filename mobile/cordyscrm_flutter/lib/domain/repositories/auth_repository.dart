import '../entities/user.dart';

/// 认证仓库接口
abstract class AuthRepository {
  /// 登录
  Future<User> login(String username, String password);

  /// 登出
  Future<void> logout();

  /// 刷新 Token
  Future<String> refreshToken();

  /// 获取当前用户
  Future<User?> getCurrentUser();

  /// 是否已登录
  Future<bool> isLoggedIn();

  /// 保存 Token
  Future<void> saveToken(String accessToken, String refreshToken);

  /// 清除 Token
  Future<void> clearToken();
}
