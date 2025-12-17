import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/enterprise_url_utils.dart';
import '../features/auth/auth_provider.dart';
import '../features/auth/login_page.dart';
import '../features/clue/clue_detail_page.dart';
import '../features/clue/clue_list_page.dart';
import '../features/customer/customer_detail_page.dart';
import '../features/customer/customer_edit_page.dart';
import '../features/customer/customer_list_page.dart';
import '../features/enterprise/enterprise_provider.dart';
import '../features/enterprise/enterprise_search_page.dart';
import '../features/enterprise/enterprise_webview_page.dart';
import '../features/home/home_shell.dart';
import '../features/opportunity/opportunity_detail_page.dart';
import '../features/opportunity/opportunity_list_page.dart';

/// 企业 WebView 路由参数
///
/// 用于传递初始 URL 和数据源类型到 EnterpriseWebViewPage。
class EnterpriseRouteParams {
  const EnterpriseRouteParams({
    this.initialUrl,
    this.dataSourceType,
  });

  /// 初始加载的 URL（用于分享链接）
  final String? initialUrl;

  /// 数据源类型（qcc/iqicha）
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
        builder: (context, state) => const HomeShell(),
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
        builder: (context, state) => const ClueListPage(),
      ),
      
      // 新建线索
      GoRoute(
        path: AppRoutes.clueNew,
        name: 'clueNew',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('新建线索 - 待实现')),
        ),
      ),
      
      // 编辑线索
      GoRoute(
        path: AppRoutes.clueEdit,
        name: 'clueEdit',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('编辑线索 - 待实现')),
        ),
      ),
      
      // 线索详情
      GoRoute(
        path: AppRoutes.clueDetail,
        name: 'clueDetail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ClueDetailPage(clueId: id);
        },
      ),
      
      // 商机列表
      GoRoute(
        path: AppRoutes.opportunityList,
        name: 'opportunityList',
        builder: (context, state) => const OpportunityListPage(),
      ),
      
      // 新建商机
      GoRoute(
        path: AppRoutes.opportunityNew,
        name: 'opportunityNew',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('新建商机 - 待实现')),
        ),
      ),
      
      // 编辑商机
      GoRoute(
        path: AppRoutes.opportunityEdit,
        name: 'opportunityEdit',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('编辑商机 - 待实现')),
        ),
      ),
      
      // 商机详情
      GoRoute(
        path: AppRoutes.opportunityDetail,
        name: 'opportunityDetail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return OpportunityDetailPage(opportunityId: id);
        },
      ),
      
      // 企业信息查询 WebView（支持多数据源）
      GoRoute(
        path: AppRoutes.enterprise,
        name: 'enterprise',
        builder: (context, state) {
          // 支持通过 extra 传递路由参数
          final extra = state.extra;
          String? initialUrl;
          EnterpriseDataSourceType? dataSourceType;

          if (extra is String) {
            // 兼容旧格式：直接传递 URL 字符串
            initialUrl = extra;
          } else if (extra is EnterpriseRouteParams) {
            // 新格式：传递路由参数对象
            initialUrl = extra.initialUrl;
            dataSourceType = extra.dataSourceType;
          }

          // 如果指定了数据源类型，更新 Provider
          if (dataSourceType != null) {
            // 使用 WidgetsBinding 延迟更新，避免在 build 期间修改状态
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(enterpriseDataSourceTypeProvider.notifier).state =
                  dataSourceType!;
            });
          }

          return EnterpriseWebViewPage(initialUrl: initialUrl);
        },
      ),

      // 企业搜索页面
      GoRoute(
        path: AppRoutes.enterpriseSearch,
        name: 'enterpriseSearch',
        builder: (context, state) => const EnterpriseSearchPage(),
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
      
      // 初始状态时，不进行重定向，等待认证状态检查完成
      if (authState.status == AuthStatus.initial) {
        return null;
      }
      
      final isLoggedIn = authState.status == AuthStatus.authenticated;
      
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
