import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

/// 后台消息处理器
///
/// 必须是顶级函数，不能是类方法
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 确保 Firebase 已初始化
  await Firebase.initializeApp();
  debugPrint('[Push] Background message: ${message.messageId}');
}

/// 推送通知服务
///
/// 负责初始化 Firebase Cloud Messaging，处理推送通知，
/// 并根据通知内容导航到相应页面。
class PushNotificationService {
  PushNotificationService({required this.router});

  /// 路由实例
  final GoRouter router;

  /// Firebase Messaging 实例
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// 本地通知插件
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Android 通知渠道
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'cordys_crm_channel',
    'CordysCRM 通知',
    description: '接收 CordysCRM 的推送通知',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  /// FCM Token
  String? _fcmToken;

  /// Token 获取回调
  Function(String token)? onTokenRefresh;

  /// 获取当前 FCM Token
  String? get fcmToken => _fcmToken;

  /// 初始化推送服务
  ///
  /// 应在应用启动时调用，在 Firebase.initializeApp() 之后。
  Future<void> initialize() async {
    // 注册后台消息处理器
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 请求通知权限
    await _requestPermission();

    // 初始化本地通知
    await _initializeLocalNotifications();

    // 创建 Android 通知渠道
    await _createNotificationChannel();

    // 获取 FCM Token
    await _getFcmToken();

    // 监听 Token 刷新
    _messaging.onTokenRefresh.listen(_handleTokenRefresh);

    // 监听前台消息
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 监听通知点击（应用在后台时）
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // 检查是否有初始通知（应用因通知而启动）
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  /// 请求通知权限
  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('[Push] Permission status: ${settings.authorizationStatus}');
  }

  /// 初始化本地通知
  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
  }

  /// 创建 Android 通知渠道
  Future<void> _createNotificationChannel() async {
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  /// 获取 FCM Token
  Future<void> _getFcmToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      debugPrint('[Push] FCM Token: $_fcmToken');

      if (_fcmToken != null) {
        onTokenRefresh?.call(_fcmToken!);
      }
    } catch (e) {
      debugPrint('[Push] Failed to get FCM token: $e');
    }
  }

  /// 处理 Token 刷新
  void _handleTokenRefresh(String token) {
    debugPrint('[Push] Token refreshed: $token');
    _fcmToken = token;
    onTokenRefresh?.call(token);
  }

  /// 处理前台消息
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[Push] Foreground message: ${message.messageId}');

    final notification = message.notification;
    if (notification == null) return;

    // 在前台显示本地通知
    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: _encodePayload(message.data),
    );
  }

  /// 处理通知点击（从 FCM）
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[Push] Notification tapped: ${message.messageId}');
    _navigateByPayload(message.data);
  }

  /// 处理通知点击（从本地通知）
  void _onNotificationTap(NotificationResponse response) {
    debugPrint('[Push] Local notification tapped: ${response.payload}');
    if (response.payload != null) {
      final data = _decodePayload(response.payload!);
      _navigateByPayload(data);
    }
  }

  /// 根据通知数据导航
  void _navigateByPayload(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final id = data['id'] as String?;

    if (type == null || id == null) {
      debugPrint('[Push] Invalid payload: $data');
      return;
    }

    switch (type) {
      case 'customer':
        router.go('/customers/$id');
        break;
      case 'clue':
        router.go('/clues/$id');
        break;
      case 'opportunity':
        router.go('/opportunities/$id');
        break;
      case 'task':
        router.go('/tasks/$id');
        break;
      default:
        debugPrint('[Push] Unknown notification type: $type');
    }
  }

  /// 编码 payload 为字符串
  String _encodePayload(Map<String, dynamic> data) {
    return data.entries.map((e) => '${e.key}=${e.value}').join('&');
  }

  /// 解码 payload 字符串
  Map<String, dynamic> _decodePayload(String payload) {
    final map = <String, dynamic>{};
    for (final part in payload.split('&')) {
      final kv = part.split('=');
      if (kv.length == 2) {
        map[kv[0]] = kv[1];
      }
    }
    return map;
  }

  /// 订阅主题
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint('[Push] Subscribed to topic: $topic');
  }

  /// 取消订阅主题
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('[Push] Unsubscribed from topic: $topic');
  }
}
