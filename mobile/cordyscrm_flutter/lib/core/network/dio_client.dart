import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/logging_interceptor.dart';

/// Dio 客户端单例
class DioClient {
  static DioClient? _instance;
  late final Dio _dio;

  DioClient._() {
    _dio = Dio(_baseOptions);
    _setupInterceptors();
  }

  /// 获取单例实例
  static DioClient get instance {
    _instance ??= DioClient._();
    return _instance!;
  }

  /// 获取 Dio 实例
  Dio get dio => _dio;

  /// 基础配置
  BaseOptions get _baseOptions => BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(milliseconds: AppConfig.connectTimeout),
        receiveTimeout: const Duration(milliseconds: AppConfig.receiveTimeout),
        sendTimeout: const Duration(milliseconds: AppConfig.sendTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

  /// 设置拦截器
  void _setupInterceptors() {
    _dio.interceptors.addAll([
      AuthInterceptor(),
      ErrorInterceptor(),
      if (AppConfig.isDebug) LoggingInterceptor(),
    ]);
  }

  /// 更新 Token
  void updateToken(String? token) {
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  /// 重置客户端
  static void reset() {
    _instance?._dio.close();
    _instance = null;
  }
}
