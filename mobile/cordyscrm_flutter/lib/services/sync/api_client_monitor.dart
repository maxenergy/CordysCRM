import 'package:flutter/foundation.dart';

import 'sync_api_client.dart';

/// API Client 监控器
///
/// 监控 API Client 的可用性状态，防止在未配置服务器时静默丢弃离线数据。
/// 当 API Client 状态变化时通知监听者。
///
/// Requirements: 6.1, 6.2, 6.3, 6.4
class ApiClientMonitor extends ChangeNotifier {
  SyncApiClient? _client;

  /// 获取当前 API Client
  SyncApiClient? get client => _client;

  /// 检查 API Client 是否可用
  ///
  /// Requirements: 6.4
  bool get isClientAvailable => _client != null;

  /// 更新 API Client
  ///
  /// 通常在用户登录后调用，设置可用的 API Client。
  /// 会通知所有监听者状态已变化。
  ///
  /// Requirements: 6.3
  void setClient(SyncApiClient client) {
    _client = client;
    notifyListeners();
  }

  /// 清除 API Client
  ///
  /// 通常在用户登出后调用，移除 API Client。
  /// 会通知所有监听者状态已变化。
  ///
  /// Requirements: 6.2
  void clearClient() {
    _client = null;
    notifyListeners();
  }
}

/// API Client 不可用异常
///
/// 当尝试同步但 API Client 不可用时抛出此异常。
/// 此异常表示应该保留队列项，等待 Client 恢复。
///
/// Requirements: 6.2, 6.5
class ClientUnavailableException implements Exception {
  final String message;

  ClientUnavailableException([
    this.message = 'API Client not available. Please configure server URL in settings.',
  ]);

  @override
  String toString() => 'ClientUnavailableException: $message';
}
