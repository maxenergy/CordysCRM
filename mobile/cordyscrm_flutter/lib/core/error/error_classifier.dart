import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import 'app_exception.dart';

/// 错误类型枚举
enum ErrorType {
  /// 可重试错误（5xx 服务器错误、网络超时等）
  retryable,

  /// 不可重试错误（4xx 客户端错误等）
  nonRetryable,

  /// 致命错误（超过最大重试次数）
  fatal,
}

/// 错误分类器配置
///
/// 用于自定义错误分类策略和重试行为
class ErrorClassifierConfig {
  const ErrorClassifierConfig({
    this.maxAttempts = 5,
    this.retryableStatusCodes = const {408, 425, 429},
    this.nonRetryableStatusCodes = const {
      400,
      401,
      403,
      404,
      409,
      422,
    },
  });

  /// 最大重试次数
  final int maxAttempts;

  /// 可重试的 HTTP 状态码集合
  /// 408: Request Timeout
  /// 425: Too Early
  /// 429: Too Many Requests
  final Set<int> retryableStatusCodes;

  /// 不可重试的 HTTP 状态码集合
  /// 400: Bad Request
  /// 401: Unauthorized
  /// 403: Forbidden
  /// 404: Not Found
  /// 409: Conflict
  /// 422: Unprocessable Entity
  final Set<int> nonRetryableStatusCodes;
}

/// 错误分类器
///
/// 用于判断同步错误是否可重试，支持多种异常类型的分类
class ErrorClassifier {
  ErrorClassifier({ErrorClassifierConfig? config})
      : _config = config ?? const ErrorClassifierConfig();

  final ErrorClassifierConfig _config;

  /// 分类错误类型
  ///
  /// 分类优先级：
  /// 1. AppException 直接分类
  /// 2. DioException.error 若为 AppException 优先处理
  /// 3. DioException 自身分类
  /// 4. SocketException/TimeoutException/FormatException/TypeError/ArgumentError
  /// 5. 默认 retryable
  ///
  /// Requirements: 4.1, 4.2, 4.3, Property 5, Property 6
  ErrorType classify(dynamic error) {
    // 1) AppException 优先
    if (error is AppException) {
      return _classifyAppException(error);
    }

    // 2) DioException，优先考虑其包裹的 error 是否为 AppException
    if (error is DioException) {
      final inner = error.error;
      if (inner is AppException) {
        return _classifyAppException(inner);
      }
      return _classifyDioException(error);
    }

    // 3) 常见系统异常
    if (error is SocketException) {
      return ErrorType.retryable;
    }
    if (error is TimeoutException) {
      return ErrorType.retryable;
    }
    
    // 4) 逻辑/格式错误不可重试
    if (error is FormatException) {
      // JSON 解析错误等，通常是数据格式问题，不应重试
      return ErrorType.nonRetryable;
    }
    if (error is TypeError) {
      // 类型错误，通常是代码逻辑问题，不应重试
      return ErrorType.nonRetryable;
    }
    if (error is ArgumentError) {
      // 参数错误，通常是代码逻辑问题，不应重试
      return ErrorType.nonRetryable;
    }

    // 5) 默认可重试
    return ErrorType.retryable;
  }

  /// 带尝试次数的分类
  ///
  /// 当尝试次数超过最大限制时，返回 fatal
  ErrorType classifyWithAttempts(dynamic error, int attemptCount) {
    if (attemptCount >= _config.maxAttempts) {
      return ErrorType.fatal;
    }
    return classify(error);
  }

  /// 判断是否应该重试
  ///
  /// 根据错误类型和当前重试次数判断是否应该继续重试
  bool shouldRetry(ErrorType type, int attemptCount) {
    if (type != ErrorType.retryable) return false;
    return attemptCount < _config.maxAttempts;
  }

  /// 分类 AppException
  ErrorType _classifyAppException(AppException error) {
    if (error is NetworkException || error is ServerException) {
      return ErrorType.retryable;
    }
    if (error is AuthException || error is ValidationException) {
      return ErrorType.nonRetryable;
    }
    if (error is CacheException) {
      return ErrorType.nonRetryable;
    }
    return ErrorType.retryable;
  }

  /// 分类 DioException
  ///
  /// Requirements: 4.1, 4.2, Property 5, Property 6
  ErrorType _classifyDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return ErrorType.retryable;
      case DioExceptionType.cancel:
        return ErrorType.nonRetryable;
      case DioExceptionType.badResponse:
        return _classifyHttpStatus(error.response?.statusCode);
      case DioExceptionType.badCertificate:
        return ErrorType.nonRetryable;
      case DioExceptionType.unknown:
        // 检查内部错误类型
        if (error.error is TypeError || 
            error.error is FormatException ||
            error.error is ArgumentError) {
          return ErrorType.nonRetryable;
        }
        // 可能是 SocketException 等，交给外层类型判断
        // 若无法识别，默认可重试
        return ErrorType.retryable;
    }
  }

  /// 分类 HTTP 状态码
  ErrorType _classifyHttpStatus(int? statusCode) {
    if (statusCode == null) return ErrorType.retryable;

    // 检查配置的可重试状态码
    if (_config.retryableStatusCodes.contains(statusCode)) {
      return ErrorType.retryable;
    }

    // 检查配置的不可重试状态码
    if (_config.nonRetryableStatusCodes.contains(statusCode)) {
      return ErrorType.nonRetryable;
    }

    // 5xx 服务器错误 - 可重试
    if (statusCode >= 500) {
      return ErrorType.retryable;
    }

    // 4xx 客户端错误 - 不可重试
    if (statusCode >= 400 && statusCode < 500) {
      return ErrorType.nonRetryable;
    }

    // 其他情况默认可重试
    return ErrorType.retryable;
  }
}
