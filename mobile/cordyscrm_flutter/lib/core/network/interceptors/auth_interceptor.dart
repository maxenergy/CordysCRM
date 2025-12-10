import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../config/storage_keys.dart';

/// 认证拦截器
/// 自动添加 JWT Token 到请求头
class AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 跳过不需要认证的接口
    if (_isPublicEndpoint(options.path)) {
      return handler.next(options);
    }

    // 获取 Token
    final token = await _storage.read(key: StorageKeys.accessToken);
    
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    return handler.next(options);
  }

  /// 判断是否为公开接口
  bool _isPublicEndpoint(String path) {
    const publicPaths = [
      '/api/auth/login',
      '/api/auth/register',
      '/api/auth/forgot-password',
    ];
    return publicPaths.any((p) => path.contains(p));
  }
}
