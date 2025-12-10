import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/login_page.dart';
import '../features/auth/auth_provider.dart';
import '../features/customer/customer_list_page.dart';
import '../features/customer/customer_detail_page.dart';
import '../features/customer/customer_edit_page.dart';

/// 路由路径常量
class AppRoutes {
  AppRoutes._();
  
  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String customerList = '/customers';
  static const String customerDetail = '/customers/:id';
  static const String customerNew = '/customers/new';
  static const String customerEdit = '/customers/edit/:id';
  static const String clueList = '/clues';
  static const String opportunityList = '/opportunities';
  static const String enterprise = '/enterprise';
  static const String profile = '/profile';
}

/// 路由刷新通知器
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Ref ref) {
    ref.listen(authProvider, (previous, next) {
      notifyListeners();
    });
  }
}

/// 路由刷新 Provider
final routerRefreshProvider = Provider<RouterRefreshNotifier>((ref) {
  return RouterRefreshNotifier(ref);
});

/// 路由配置 Provider
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(routerRefreshProvider);
  
  return GoRouter(
    initialLocation: AppRoutes.login,
    debugLogDiagnostics: true,
    refreshListenable: refreshNotifier,
    routes: [
      // 登录页
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      
      // 首页（底部导航）
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('首页 - 待实现')),
        ),
      ),
      
      // 客户列表
      GoRoute(
        path: AppRoutes.customerList,
        name: 'customerList',
        builder: (context, state) => const CustomerListPage(),
      ),
      
      // 新建客户
      GoRoute(
        path: AppRoutes.customerNew,
        name: 'customerNew',
        builder: (context, state) => const CustomerEditPage(),
      ),
      
      // 编辑客户
      GoRoute(
        path: AppRoutes.customerEdit,
        name: 'customerEdit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CustomerEditPage(customerId: id);
        },
      ),
      
      // 客户详情
      GoRoute(
        path: AppRoutes.customerDetail,
        name: 'customerDetail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CustomerDetailPage(customerId: id);
        },
      ),
      
      // 线索列表
      GoRoute(
        path: AppRoutes.clueList,
        name: 'clueList',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('线索列表 - 待实现')),
        ),
      ),
      
      // 商机列表
      GoRoute(
        path: AppRoutes.opportunityList,
        name: 'opportunityList',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('商机列表 - 待实现')),
        ),
      ),
      
      // 企业信息查询
      GoRoute(
        path: AppRoutes.enterprise,
        name: 'enterprise',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('企业信息查询 - 待实现')),
        ),
      ),
    ],
    
    // 错误页面
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('页面不存在: ${state.uri}'),
      ),
    ),
    
    // 路由重定向（认证守卫）
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isLoggedIn = authState.status == AuthStatus.authenticated;
      final isLoginRoute = state.matchedLocation == AppRoutes.login;
      
      // 未登录且不在登录页，重定向到登录页
      if (!isLoggedIn && !isLoginRoute) {
        return AppRoutes.login;
      }
      
      // 已登录且在登录页，重定向到首页
      if (isLoggedIn && isLoginRoute) {
        return AppRoutes.home;
      }
      
      return null;
    },
  );
});
