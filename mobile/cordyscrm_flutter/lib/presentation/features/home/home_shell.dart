import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dashboard/dashboard_page.dart';
import '../customer/customer_list_page.dart';
import '../clue/clue_list_page.dart';
import '../opportunity/opportunity_list_page.dart';
import '../enterprise/enterprise_search_with_webview_page.dart';
import 'profile_page.dart';

/// 底部导航项配置
class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// 底部导航配置
const List<_NavItem> _navItems = [
  _NavItem(
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    label: '工作台',
  ),
  _NavItem(
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
    label: '客户',
  ),
  _NavItem(
    icon: Icons.lightbulb_outline,
    selectedIcon: Icons.lightbulb,
    label: '线索',
  ),
  _NavItem(
    icon: Icons.business_center_outlined,
    selectedIcon: Icons.business_center,
    label: '商机',
  ),
  _NavItem(
    icon: Icons.search_outlined,
    selectedIcon: Icons.search,
    label: '企业查询',
  ),
  _NavItem(
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    label: '我的',
  ),
];

/// 首页 Shell - 包含底部导航栏的主框架
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _selectedIndex = 0;

  /// 页面列表 - 使用 late 延迟初始化以支持状态保持
  late final List<Widget> _pages = const [
    DashboardPage(),
    CustomerListPage(),
    ClueListPage(),
    OpportunityListPage(),
    EnterpriseSearchWithWebViewPage(),
    ProfilePage(),
  ];

  void _onDestinationSelected(int index) {
    if (index != _selectedIndex) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: _navItems
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
}
