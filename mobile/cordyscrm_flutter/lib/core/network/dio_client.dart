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
  String _baseUrl = AppConfig.baseUrl;

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
  
  /// 获取当前 baseUrl
  String get baseUrl => _baseUrl;

  /// 基础配置
  BaseOptions get _baseOptions => BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(milliseconds: AppConfig.connectTimeout),
        receiveTimeout: const Duration(milliseconds: AppConfig.receiveTimeout),
        sendTimeout: const Duration(milliseconds: AppConfig.sendTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
  
  /// 更新服务器地址
  void updateBaseUrl(String url) {
    _baseUrl = url;
    _dio.options.baseUrl = url;
  }

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
  /// 注意：Flutter 使用 Bearer token 认证，不需要 CSRF Token
  /// 后端 CsrfFilter 会检测 Authorization: Bearer xxx 并跳过 CSRF 验证
  /// 因此不再设置 CSRF-TOKEN 头，避免后端尝试解密无效的 token
  void updateToken(String? token) {
    _csrfToken = token;
    // 不设置 CSRF-TOKEN 头，因为 Flutter 使用 Bearer token 认证
    // 后端会根据 Authorization 头跳过 CSRF 验证
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
