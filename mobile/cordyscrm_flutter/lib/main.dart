import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'presentation/routing/app_router.dart';
import 'presentation/theme/app_theme.dart';
import 'services/share/share_handler.dart';

/// 全局分享处理器
ShareHandler? _shareHandler;

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
  
  // 创建 ProviderContainer 以在 main 函数中访问 provider
  final container = ProviderContainer();
  
  // 获取路由实例并初始化分享处理
  final router = container.read(appRouterProvider);
  _initializeShareHandler(router);
  
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: CordysCRMApp(router: router),
    ),
  );
}

/// 初始化分享处理器
void _initializeShareHandler(GoRouter router) {
  _shareHandler = ShareHandler(router: router);
  _shareHandler!.initialize();
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
