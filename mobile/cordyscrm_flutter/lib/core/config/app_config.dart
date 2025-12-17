/// 应用配置
class AppConfig {
  /// API 基础地址
  /// 开发环境使用本地地址，生产环境使用正式地址
  static const String baseUrl = 'http://127.0.0.1:8081'; // USB 调试使用 adb reverse
  
  /// 请求超时时间（毫秒）
  static const int connectTimeout = 15000;
  static const int receiveTimeout = 15000;
  static const int sendTimeout = 15000;
  
  /// 分页大小
  static const int pageSize = 20;
  
  /// Token 刷新阈值（秒）
  static const int tokenRefreshThreshold = 300;
  
  /// 爱企查 WebView URL
  static const String aiqichaUrl = 'https://aiqicha.baidu.com';
  
  /// 是否为调试模式
  static const bool isDebug = true;
}
