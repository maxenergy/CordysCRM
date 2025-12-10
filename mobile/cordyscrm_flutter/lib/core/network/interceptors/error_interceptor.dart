import 'package:dio/dio.dart';
import '../../error/error_handler.dart';

/// 错误拦截器
/// 统一处理网络错误
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final appException = ErrorHandler.handleDioError(err);
    
    // 转换为 DioException 以便上层处理
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: appException,
        message: appException.message,
      ),
    );
  }
}
