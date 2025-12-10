import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/config/storage_keys.dart';
import '../../core/network/dio_client.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/auth_models.dart';

/// 认证仓库实现
class AuthRepositoryImpl implements AuthRepository {
  final FlutterSecureStorage _storage;
  final DioClient _dioClient;

  AuthRepositoryImpl({
    FlutterSecureStorage? storage,
    DioClient? dioClient,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _dioClient = dioClient ?? DioClient.instance;

  @override
  Future<User> login(String username, String password) async {
    final request = LoginRequest(username: username, password: password);
    
    final response = await _dioClient.dio.post(
      '/api/auth/login',
      data: request.toJson(),
    );

    final loginResponse = LoginResponse.fromJson(response.data);

    // 保存 Token
    await saveToken(loginResponse.accessToken, loginResponse.refreshToken);

    // 保存用户信息
    await _storage.write(
      key: StorageKeys.userInfo,
      value: jsonEncode(loginResponse.user.toJson()),
    );

    // 更新 Dio 客户端的 Token
    _dioClient.updateToken(loginResponse.accessToken);

    return loginResponse.user.toEntity();
  }

  @override
  Future<void> logout() async {
    try {
      await _dioClient.dio.post('/api/auth/logout');
    } catch (_) {
      // 忽略登出 API 错误
    } finally {
      await clearToken();
      _dioClient.updateToken(null);
    }
  }

  @override
  Future<String> refreshToken() async {
    final refreshToken = await _storage.read(key: StorageKeys.refreshToken);
    
    if (refreshToken == null) {
      throw Exception('No refresh token available');
    }

    final response = await _dioClient.dio.post(
      '/api/auth/refresh',
      data: {'refreshToken': refreshToken},
    );

    final newAccessToken = response.data['accessToken'] ?? response.data['access_token'];
    final newRefreshToken = response.data['refreshToken'] ?? response.data['refresh_token'] ?? refreshToken;

    await saveToken(newAccessToken, newRefreshToken);
    _dioClient.updateToken(newAccessToken);

    return newAccessToken;
  }

  @override
  Future<User?> getCurrentUser() async {
    final userJson = await _storage.read(key: StorageKeys.userInfo);
    
    if (userJson == null) {
      return null;
    }

    try {
      final userMap = jsonDecode(userJson) as Map<String, dynamic>;
      return UserModel.fromJson(userMap).toEntity();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: StorageKeys.accessToken);
    return token != null && token.isNotEmpty;
  }

  @override
  Future<void> saveToken(String accessToken, String refreshToken) async {
    await _storage.write(key: StorageKeys.accessToken, value: accessToken);
    await _storage.write(key: StorageKeys.refreshToken, value: refreshToken);
  }

  @override
  Future<void> clearToken() async {
    await _storage.delete(key: StorageKeys.accessToken);
    await _storage.delete(key: StorageKeys.refreshToken);
    await _storage.delete(key: StorageKeys.userInfo);
  }
}
