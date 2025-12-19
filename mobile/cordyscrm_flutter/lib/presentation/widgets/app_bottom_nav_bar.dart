import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 底部导航项配置
class NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;

  const NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.route,
  });
}

/// 底部导航配置
const List<NavItem> appNavItems = [
  NavItem(
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    label: '工作台',
    route: '/home',
  ),
  NavItem(
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
    label: '客户',
    route: '/customers',
  ),
  NavItem(
    icon: Icons.lightbulb_outline,
    selectedIcon: Icons.lightbulb,
    label: '线索',
    route: '/clues',
  ),
  NavItem(
    icon: Icons.business_center_outlined,
    selectedIcon: Icons.business_center,
    label: '商机',
    route: '/opportunities',
  ),
  NavItem(
    icon: Icons.search_outlined,
    selectedIcon: Icons.search,
    label: '企业查询',
    route: '/enterprise/search',
  ),
  NavItem(
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    label: '我的',
    route: '/profile',
  ),
];

/// 可复用的底部导航栏组件
/// 
/// 用于在子页面中保持底部导航栏的一致性。
/// 支持高亮当前所属模块，并在切换时提供确认弹窗（可选）。
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.currentModule,
    this.onNavigate,
    this.confirmBeforeNavigate = false,
    this.confirmMessage,
  });

  /// 当前所属模块索引（0-5）
  final int currentModule;

  /// 自定义导航回调，返回 true 允许导航，返回 false 阻止导航
  final Future<bool> Function(int index)? onNavigate;

  /// 是否在导航前显示确认弹窗
  final bool confirmBeforeNavigate;

  /// 确认弹窗的提示消息
  final String? confirmMessage;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentModule,
      onDestinationSelected: (index) => _handleNavigation(context, index),
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
    );
  }

  Future<void> _handleNavigation(BuildContext context, int index) async {
    // 如果点击的是当前模块，不做任何操作
    if (index == currentModule) return;

    // 如果有自定义导航回调，先执行
    if (onNavigate != null) {
      final shouldNavigate = await onNavigate!(index);
      if (!shouldNavigate) return;
    }

    // 如果需要确认，显示弹窗
    if (confirmBeforeNavigate) {
      if (!context.mounted) return;
      final confirmed = await _showConfirmDialog(context);
      if (!confirmed) return;
    }

    // 执行导航
    if (!context.mounted) return;
    final route = appNavItems[index].route;
    // 使用 go 而不是 push，这样会替换当前路由栈
    context.go(route);
  }

  Future<bool> _showConfirmDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认离开'),
        content: Text(confirmMessage ?? '当前页面有未保存的内容，确定要离开吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

/// 模块索引常量
class ModuleIndex {
  ModuleIndex._();
  
  static const int dashboard = 0;
  static const int customer = 1;
  static const int clue = 2;
  static const int opportunity = 3;
  static const int enterprise = 4;
  static const int profile = 5;
}
