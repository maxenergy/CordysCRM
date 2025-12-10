import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'app_exception.dart';

/// 错误处理器
class ErrorHandler {
  static final Logger _logger = Logger();

  /// 处理 Dio 异常
  static AppException handleDioError(DioException error) {
    _logger.e('DioException: ${error.type}', error: error, stackTrace: error.stackTrace);

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkException(
          message: '网络连接超时，请检查网络设置',
          code: 'TIMEOUT',
        );

      case DioExceptionType.connectionError:
        return const NetworkException(
          message: '网络连接失败，请检查网络设置',
          code: 'CONNECTION_ERROR',
        );

      case DioExceptionType.badResponse:
        return _handleBadResponse(error.response);

      case DioExceptionType.cancel:
        return const NetworkException(
          message: '请求已取消',
          code: 'CANCELLED',
        );

      default:
        return NetworkException(
          message: '网络请求失败: ${error.message}',
          code: 'UNKNOWN',
          originalError: error,
        );
    }
  }

  /// 处理错误响应
  static AppException _handleBadResponse(Response? response) {
    if (response == null) {
      return const ServerException(
        message: '服务器无响应',
        code: 'NO_RESPONSE',
      );
    }

    final statusCode = response.statusCode;
    final data = response.data;

    // 尝试从响应中提取错误信息
    String message = '服务器错误';
    String? code;

    if (data is Map<String, dynamic>) {
      message = data['message'] ?? data['error'] ?? message;
      code = data['code']?.toString();
    }

    switch (statusCode) {
      case 400:
        return ValidationException(
          message: message,
          code: code ?? 'BAD_REQUEST',
        );

      case 401:
        return AuthException(
          message: '登录已过期，请重新登录',
          code: code ?? 'UNAUTHORIZED',
        );

      case 403:
        return AuthException(
          message: '没有权限访问',
          code: code ?? 'FORBIDDEN',
        );

      case 404:
        return ServerException(
          message: '请求的资源不存在',
          code: code ?? 'NOT_FOUND',
        );

      case 409:
        return ServerException(
          message: message,
          code: code ?? 'CONFLICT',
        );

      case 500:
      case 502:
      case 503:
        return ServerException(
          message: '服务器繁忙，请稍后重试',
          code: code ?? 'SERVER_ERROR',
        );

      default:
        return ServerException(
          message: message,
          code: code ?? 'UNKNOWN',
        );
    }
  }

  /// 处理通用异常
  static AppException handleError(dynamic error) {
    _logger.e('Error: $error');

    if (error is AppException) {
      return error;
    }

    if (error is DioException) {
      return handleDioError(error);
    }

    return NetworkException(
      message: error.toString(),
      code: 'UNKNOWN',
      originalError: error,
    );
  }
}
