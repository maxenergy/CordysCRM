import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

/// 日志拦截器
/// 记录请求和响应日志
class LoggingInterceptor extends Interceptor {
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
    ),
  );

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _logger.i(
      '┌─────────────────────────────────────────────────────────────────────\n'
      '│ REQUEST: ${options.method} ${options.uri}\n'
      '│ Headers: ${_formatHeaders(options.headers)}\n'
      '│ Data: ${_formatData(options.data)}\n'
      '└─────────────────────────────────────────────────────────────────────',
    );
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _logger.i(
      '┌─────────────────────────────────────────────────────────────────────\n'
      '│ RESPONSE: ${response.statusCode} ${response.requestOptions.uri}\n'
      '│ Data: ${_formatData(response.data)}\n'
      '└─────────────────────────────────────────────────────────────────────',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.e(
      '┌─────────────────────────────────────────────────────────────────────\n'
      '│ ERROR: ${err.type} ${err.requestOptions.uri}\n'
      '│ Message: ${err.message}\n'
      '│ Response: ${_formatData(err.response?.data)}\n'
      '└─────────────────────────────────────────────────────────────────────',
    );
    handler.next(err);
  }

  String _formatHeaders(Map<String, dynamic> headers) {
    final filtered = Map<String, dynamic>.from(headers);
    // 隐藏敏感信息
    if (filtered.containsKey('Authorization')) {
      filtered['Authorization'] = '***';
    }
    return filtered.toString();
  }

  String _formatData(dynamic data) {
    if (data == null) return 'null';
    if (data is Map || data is List) {
      try {
        final encoder = const JsonEncoder.withIndent('  ');
        final str = encoder.convert(data);
        // 截断过长的数据
        if (str.length > 500) {
          return '${str.substring(0, 500)}... (truncated)';
        }
        return str;
      } catch (_) {
        return data.toString();
      }
    }
    return data.toString();
  }
}
