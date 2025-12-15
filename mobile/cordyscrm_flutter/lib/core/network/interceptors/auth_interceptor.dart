import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import '../../config/storage_keys.dart';

/// 认证拦截器
/// 自动添加 Session Token 到请求头
class AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 跳过不需要认证的接口
    if (_isPublicEndpoint(options.path)) {
      return handler.next(options);
    }

    // 获取 Session Token
    final token = await _storage.read(key: StorageKeys.accessToken);
    
    if (token != null && token.isNotEmpty) {
      // 使用 Bearer 格式传递 Session ID
      options.headers['Authorization'] = 'Bearer $token';
      
      // 同时设置 x-auth-token 头（后端可能需要）
      options.headers['x-auth-token'] = token;
      
      _logger.d('添加认证头: Authorization=Bearer ${token.substring(0, 8)}...');
    } else {
      _logger.w('未找到认证 Token，请先登录');
    }

    return handler.next(options);
  }

  /// 判断是否为公开接口
  bool _isPublicEndpoint(String path) {
    const publicPaths = [
      '/login',
      '/logout',
      '/get-key',
      '/is-login',
      '/api/auth/login',
      '/api/auth/register',
      '/api/auth/forgot-password',
      '/anonymous/',
    ];
    return publicPaths.any((p) => path.contains(p));
  }
}
