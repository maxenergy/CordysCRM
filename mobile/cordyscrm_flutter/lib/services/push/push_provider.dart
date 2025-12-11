import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/routing/app_router.dart';
import 'push_notification_service.dart';

/// 推送通知服务 Provider
///
/// 提供全局的推送通知服务实例。
/// 注意：需要在 Firebase.initializeApp() 之后初始化。
final pushNotificationServiceProvider =
    Provider<PushNotificationService>((ref) {
  final router = ref.watch(appRouterProvider);
  return PushNotificationService(router: router);
});

/// FCM Token Provider
///
/// 提供当前的 FCM Token，用于上报到后端。
final fcmTokenProvider = StateProvider<String?>((ref) => null);

/// 推送通知状态
class PushNotificationState {
  const PushNotificationState({
    this.isInitialized = false,
    this.hasPermission = false,
    this.fcmToken,
    this.error,
  });

  /// 是否已初始化
  final bool isInitialized;

  /// 是否有通知权限
  final bool hasPermission;

  /// FCM Token
  final String? fcmToken;

  /// 错误信息
  final String? error;

  PushNotificationState copyWith({
    bool? isInitialized,
    bool? hasPermission,
    String? fcmToken,
    String? error,
    bool clearError = false,
  }) {
    return PushNotificationState(
      isInitialized: isInitialized ?? this.isInitialized,
      hasPermission: hasPermission ?? this.hasPermission,
      fcmToken: fcmToken ?? this.fcmToken,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 推送通知状态 Notifier
class PushNotificationNotifier extends StateNotifier<PushNotificationState> {
  PushNotificationNotifier(this._service)
      : super(const PushNotificationState()) {
    _service.onTokenRefresh = _onTokenRefresh;
  }

  final PushNotificationService _service;

  /// 初始化推送服务
  Future<void> initialize() async {
    try {
      await _service.initialize();
      state = state.copyWith(
        isInitialized: true,
        hasPermission: true,
        fcmToken: _service.fcmToken,
      );
    } catch (e) {
      state = state.copyWith(
        isInitialized: true,
        error: '推送服务初始化失败: $e',
      );
    }
  }

  /// Token 刷新回调
  void _onTokenRefresh(String token) {
    state = state.copyWith(fcmToken: token);
  }

  /// 订阅主题
  Future<void> subscribeToTopic(String topic) async {
    await _service.subscribeToTopic(topic);
  }

  /// 取消订阅主题
  Future<void> unsubscribeFromTopic(String topic) async {
    await _service.unsubscribeFromTopic(topic);
  }
}

/// 推送通知状态 Provider
final pushNotificationProvider =
    StateNotifierProvider<PushNotificationNotifier, PushNotificationState>(
        (ref) {
  final service = ref.watch(pushNotificationServiceProvider);
  return PushNotificationNotifier(service);
});
