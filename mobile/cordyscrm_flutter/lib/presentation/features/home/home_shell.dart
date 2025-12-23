import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routing/app_router.dart';
import '../../widgets/app_bottom_nav_bar.dart';

/// 首页 Shell - 包含底部导航栏的主框架
/// 
/// 使用 go_router 的 ShellRoute 模式，为所有子页面提供统一的底部导航栏。
class HomeShell extends StatelessWidget {
  const HomeShell({
    required this.child,
    super.key,
  });

  /// 由 go_router 提供的要在 Scaffold 主体中显示的 Widget
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 600;
        final selectedIndex = _calculateSelectedIndex(context);

        if (isDesktop) {
          // Desktop layout with NavigationRail
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) => _onDestinationSelected(index, context),
                  labelType: NavigationRailLabelType.selected,
                  destinations: appNavItems
                      .map(
                        (item) => NavigationRailDestination(
                          icon: Icon(item.icon),
                          selectedIcon: Icon(item.selectedIcon),
                          label: Text(item.label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: child),
              ],
            ),
          );
        } else {
          // Mobile layout with BottomNavigationBar
          return Scaffold(
            body: child,
            bottomNavigationBar: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => _onDestinationSelected(index, context),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: appNavItems
                  .map(
                    (item) => NavigationDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.selectedIcon),
                      label: item.label,
                    ),
                  )
                  .toList(),
            ),
          );
        }
      },
    );
  }

  /// 根据当前路由计算选中的导航项索引
  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    
    // 按优先级匹配路由
    if (location.startsWith(AppRoutes.customerList)) {
      return ModuleIndex.customer;
    }
    if (location.startsWith(AppRoutes.clueList)) {
      return ModuleIndex.clue;
    }
    if (location.startsWith(AppRoutes.opportunityList)) {
      return ModuleIndex.opportunity;
    }
    if (location.startsWith(AppRoutes.enterpriseSearch)) {
      return ModuleIndex.enterprise;
    }
    if (location.startsWith(AppRoutes.profile)) {
      return ModuleIndex.profile;
    }
    if (location.startsWith(AppRoutes.home)) {
      return ModuleIndex.dashboard;
    }
    
    return ModuleIndex.dashboard; // 默认返回仪表盘
  }

  /// 处理导航项选择事件
  void _onDestinationSelected(int index, BuildContext context) {
    switch (index) {
      case ModuleIndex.dashboard:
        context.go(AppRoutes.home);
        break;
      case ModuleIndex.customer:
        context.go(AppRoutes.customerList);
        break;
      case ModuleIndex.clue:
        context.go(AppRoutes.clueList);
        break;
      case ModuleIndex.opportunity:
        context.go(AppRoutes.opportunityList);
        break;
      case ModuleIndex.enterprise:
        context.go(AppRoutes.enterpriseSearch);
        break;
      case ModuleIndex.profile:
        context.go(AppRoutes.profile);
        break;
    }
  }
}
