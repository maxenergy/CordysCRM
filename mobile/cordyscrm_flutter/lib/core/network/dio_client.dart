import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import '../config/app_config.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/logging_interceptor.dart';

/// Dio 客户端单例
class DioClient {
  static DioClient? _instance;
  late final Dio _dio;
  late final CookieJar _cookieJar;
  String? _csrfToken;

  DioClient._() {
    _cookieJar = CookieJar();
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

  /// 获取 CookieJar
  CookieJar get cookieJar => _cookieJar;

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
    // Cookie 管理器必须在最前面
    _dio.interceptors.add(CookieManager(_cookieJar));
    _dio.interceptors.addAll([
      AuthInterceptor(),
      ErrorInterceptor(),
      if (AppConfig.isDebug) LoggingInterceptor(),
    ]);
  }

  /// 更新 CSRF Token
  void updateToken(String? token) {
    _csrfToken = token;
    if (token != null) {
      _dio.options.headers['CSRF-TOKEN'] = token;
    } else {
      _dio.options.headers.remove('CSRF-TOKEN');
    }
  }

  /// 获取 CSRF Token
  String? get csrfToken => _csrfToken;

  /// 清除 Cookie
  Future<void> clearCookies() async {
    await _cookieJar.deleteAll();
  }

  /// 重置客户端
  static void reset() {
    _instance?._dio.close();
    _instance = null;
  }
}
