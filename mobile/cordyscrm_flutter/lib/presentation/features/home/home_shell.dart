import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/app_bottom_nav_bar.dart';
import '../dashboard/dashboard_page.dart';
import '../customer/customer_list_page.dart';
import '../clue/clue_list_page.dart';
import '../opportunity/opportunity_list_page.dart';
import '../enterprise/enterprise_search_with_webview_page.dart';
import 'profile_page.dart';

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
}
