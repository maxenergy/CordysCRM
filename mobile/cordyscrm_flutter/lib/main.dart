import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/services/enterprise_settings_service.dart';
import 'presentation/features/enterprise/enterprise_provider.dart';
import 'presentation/routing/app_router.dart';
import 'presentation/theme/app_theme.dart';
import 'services/push/push_provider.dart';
import 'services/share/share_handler.dart';

/// 全局分享处理器
ShareHandler? _shareHandler;

/// Firebase 是否已初始化
bool _firebaseInitialized = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 设置状态栏样式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  
  // 设置屏幕方向
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // 初始化 Firebase（如果配置文件存在）
  await _initializeFirebase();

  // 初始化 SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  
  // 创建 ProviderContainer 以在 main 函数中访问 provider
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );

  // 恢复用户的数据源选择
  _restoreEnterpriseDataSource(container);
  
  // 获取路由实例并初始化分享处理
  final router = container.read(appRouterProvider);
  _initializeShareHandler(router, container);
  
  // 初始化推送服务（如果 Firebase 已初始化）
  if (_firebaseInitialized) {
    _initializePushNotifications(container);
  }
  
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: CordysCRMApp(router: router),
    ),
  );
}

/// 初始化 Firebase
///
/// 如果 Firebase 配置文件不存在，会静默失败并记录日志。
Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp();
    _firebaseInitialized = true;
    debugPrint('[Firebase] Initialized successfully');
  } catch (e) {
    debugPrint('[Firebase] Initialization failed: $e');
    debugPrint('[Firebase] Push notifications will be disabled');
    // 不抛出异常，允许应用继续运行
  }
}

/// 初始化推送通知服务
void _initializePushNotifications(ProviderContainer container) {
  // 延迟初始化，确保应用已完全启动
  Future.delayed(const Duration(seconds: 1), () {
    container.read(pushNotificationProvider.notifier).initialize();
  });
}

/// 初始化分享处理器
void _initializeShareHandler(GoRouter router, ProviderContainer container) {
  _shareHandler = ShareHandler(router: router, container: container);
  _shareHandler!.initialize();
}

/// 恢复用户的数据源选择
void _restoreEnterpriseDataSource(ProviderContainer container) {
  final settingsService = container.read(enterpriseSettingsServiceProvider);
  final savedType = settingsService.getDataSourceType();
  container.read(enterpriseDataSourceTypeProvider.notifier).state = savedType;
  debugPrint('[Enterprise] Restored data source: $savedType');
}

/// CordysCRM 应用
class CordysCRMApp extends StatefulWidget {
  const CordysCRMApp({super.key, required this.router});

  final GoRouter router;

  @override
  State<CordysCRMApp> createState() => _CordysCRMAppState();
}

class _CordysCRMAppState extends State<CordysCRMApp> {
  @override
  void dispose() {
    // 释放分享处理器资源
    _shareHandler?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'CordysCRM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: widget.router,
    );
  }
}
