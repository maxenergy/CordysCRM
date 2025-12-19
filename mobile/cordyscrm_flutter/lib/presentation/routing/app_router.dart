import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/enterprise_url_utils.dart';
import '../features/auth/auth_provider.dart';
import '../features/auth/login_page.dart';
import '../features/clue/clue_detail_page.dart';
import '../features/clue/clue_edit_page.dart';
import '../features/clue/clue_list_page.dart';
import '../features/customer/customer_detail_page.dart';
import '../features/customer/customer_edit_page.dart';
import '../features/customer/customer_list_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/enterprise/enterprise_provider.dart';
import '../features/enterprise/enterprise_search_with_webview_page.dart';
import '../features/enterprise/enterprise_webview_page.dart';
import '../features/home/home_shell.dart';
import '../features/home/profile_page.dart';
import '../features/opportunity/opportunity_detail_page.dart';
import '../features/opportunity/opportunity_edit_page.dart';
import '../features/opportunity/opportunity_list_page.dart';

/// 企业 WebView 路由参数
class EnterpriseRouteParams {
  const EnterpriseRouteParams({
    this.initialUrl,
    this.dataSourceType,
  });

  final String? initialUrl;
  final EnterpriseDataSourceType? dataSourceType;
}

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
  static const String clueDetail = '/clues/:id';
  static const String clueNew = '/clues/new';
  static const String clueEdit = '/clues/edit/:id';
  static const String opportunityList = '/opportunities';
  static const String opportunityDetail = '/opportunities/:id';
  static const String opportunityNew = '/opportunities/new';
  static const String opportunityEdit = '/opportunities/edit/:id';
  static const String enterprise = '/enterprise';
  static const String enterpriseSearch = '/enterprise/search';
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

/// Shell Navigator Key - 用于嵌套导航
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

/// 路由配置 Provider
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(routerRefreshProvider);
  
  return GoRouter(
    initialLocation: AppRoutes.login,
    debugLogDiagnostics: true,
    refreshListenable: refreshNotifier,
    routes: [
      // 登录页（Shell 外部）
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      
      // 主应用 Shell - 包含底部导航栏
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return HomeShell(child: child);
        },
        routes: [
          // 仪表盘（首页）
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            builder: (context, state) => const DashboardPage(),
          ),
          
          // 客户模块
          GoRoute(
            path: AppRoutes.customerList,
            name: 'customerList',
            builder: (context, state) => const CustomerListPage(),
            routes: [
              // 新建客户
              GoRoute(
                path: 'new',
                name: 'customerNew',
                parentNavigatorKey: _shellNavigatorKey,
                builder: (context, state) => const CustomerEditPage(),
              ),
              // 编辑客户
              GoRoute(
                path: 'edit/:id',
                name: 'customerEdit',
                parentNavigatorKey: _shellNavigatorKey,
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return CustomerEditPage(customerId: id);
                },
              ),
              // 客户详情
              GoRoute(
                path: ':id',
                name: 'customerDetail',
                parentNavigatorKey: _shellNavigatorKey,
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return CustomerDetailPage(customerId: id);
                },
              ),
            ],
          ),
          
          // 线索模块
          GoRoute(
            path: AppRoutes.clueList,
            name: 'clueList',
            builder: (context, state) => const ClueListPage(),
            routes: [
              // 新建线索
              GoRoute(
                path: 'new',
                name: 'clueNew',
                parentNavigatorKey: _shellNavigatorKey,
                builder: (context, state) => const ClueEditPage(),
              ),
              // 编辑线索
              GoRoute(
                path: 'edit/:id',
                name: 'clueEdit',
                parentNavigatorKey: _shellNavigatorKey,
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return ClueEditPage(clueId: id);
                },
              ),
              // 线索详情
              GoRoute(
                path: ':id',
                name: 'clueDetail',
                parentNavigatorKey: _shellNavigatorKey,
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return ClueDetailPage(clueId: id);
                },
              ),
            ],
          ),
          
          // 商机模块
          GoRoute(
            path: AppRoutes.opportunityList,
            name: 'opportunityList',
            builder: (context, state) => const OpportunityListPage(),
            routes: [
              // 新建商机
              GoRoute(
                path: 'new',
                name: 'opportunityNew',
                parentNavigatorKey: _shellNavigatorKey,
                builder: (context, state) => const OpportunityEditPage(),
              ),
              // 编辑商机
              GoRoute(
                path: 'edit/:id',
                name: 'opportunityEdit',
                parentNavigatorKey: _shellNavigatorKey,
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return OpportunityEditPage(opportunityId: id);
                },
              ),
              // 商机详情
              GoRoute(
                path: ':id',
                name: 'opportunityDetail',
                parentNavigatorKey: _shellNavigatorKey,
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return OpportunityDetailPage(opportunityId: id);
                },
              ),
            ],
          ),
          
          // 企业搜索
          GoRoute(
            path: AppRoutes.enterpriseSearch,
            name: 'enterpriseSearch',
            builder: (context, state) => const EnterpriseSearchWithWebViewPage(),
          ),
          
          // 个人中心
          GoRoute(
            path: AppRoutes.profile,
            name: 'profile',
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),
      
      // 企业 WebView（Shell 外部，全屏显示）
      GoRoute(
        path: AppRoutes.enterprise,
        name: 'enterprise',
        builder: (context, state) {
          final extra = state.extra;
          String? initialUrl;
          EnterpriseDataSourceType? dataSourceType;

          if (extra is String) {
            initialUrl = extra;
          } else if (extra is EnterpriseRouteParams) {
            initialUrl = extra.initialUrl;
            dataSourceType = extra.dataSourceType;
          }

          if (dataSourceType != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(enterpriseDataSourceTypeProvider.notifier).state =
                  dataSourceType!;
            });
          }

          return EnterpriseWebViewPage(initialUrl: initialUrl);
        },
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
      final isLoginRoute = state.matchedLocation == AppRoutes.login;
      
      if (authState.status == AuthStatus.initial) {
        return null;
      }
      
      final isLoggedIn = authState.status == AuthStatus.authenticated;
      
      if (!isLoggedIn && !isLoginRoute) {
        return AppRoutes.login;
      }
      
      if (isLoggedIn && isLoginRoute) {
        return AppRoutes.home;
      }
      
      return null;
    },
  );
});
