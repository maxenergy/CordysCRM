import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import 'dashboard_provider.dart';

/// Dashboard（仪表盘）页面
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dataAsync = ref.watch(dashboardDataProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('工作台'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: () => ref.invalidate(dashboardDataProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardDataProvider);
          await ref.read(dashboardDataProvider.future);
        },
        child: dataAsync.when(
          loading: () => _buildLoading(),
          error: (error, _) => _buildError(error, isDark),
          data: (data) => _buildContent(context, ref, data, isDark),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: const [
        SizedBox(height: 80),
        Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildError(Object error, bool isDark) {
    final subtitleColor = isDark ? Colors.white70 : AppTheme.textSecondary;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.error_outline, size: 48, 
            color: isDark ? Colors.white70 : AppTheme.errorColor),
        const SizedBox(height: 12),
        Text('加载失败，请下拉重试', 
            style: TextStyle(color: subtitleColor), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, 
      DashboardData data, bool isDark) {
    final titleColor = isDark ? Colors.white : AppTheme.textPrimary;
    final subtitleColor = isDark ? Colors.white70 : AppTheme.textSecondary;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        _SectionHeader(title: '关键指标', subtitle: '今日 / 本月概览', 
            titleColor: titleColor, subtitleColor: subtitleColor),
        const SizedBox(height: 12),
        _KpiRow(kpi: data.kpi, isDark: isDark),
        const SizedBox(height: 20),

        _SectionHeader(title: '快捷操作', subtitle: '常用入口', 
            titleColor: titleColor, subtitleColor: subtitleColor),
        const SizedBox(height: 12),
        _QuickActionsGrid(
          actions: data.quickActions,
          onActionTap: (action) => _handleQuickAction(context, action),
          isDark: isDark,
        ),
        const SizedBox(height: 20),

        _SectionHeader(title: '今日待办', subtitle: '需要优先处理', 
            titleColor: titleColor, subtitleColor: subtitleColor),
        const SizedBox(height: 12),
        _TodoList(
          todos: data.todos,
          isDark: isDark,
          onTapTodo: (todo) => _handleTodoTap(context, todo),
        ),
      ],
    );
  }

  void _handleQuickAction(BuildContext context, DashboardQuickAction action) {
    switch (action) {
      case DashboardQuickAction.newCustomer:
        context.push('/customers/new');
      case DashboardQuickAction.newClue:
        context.push('/clues/new');
      case DashboardQuickAction.newOpportunity:
        context.push('/opportunities/new');
      case DashboardQuickAction.writeFollowUp:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('写跟进功能开发中')),
        );
    }
  }

  void _handleTodoTap(BuildContext context, DashboardTodo todo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('待办：${todo.title}')),
    );
  }
}


/// 区域标题组件
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.titleColor,
    required this.subtitleColor,
  });

  final String title;
  final String subtitle;
  final Color titleColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(title, style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w700, color: titleColor)),
        ),
        Text(subtitle, style: TextStyle(fontSize: 12, color: subtitleColor)),
      ],
    );
  }
}

/// KPI 卡片行
class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.kpi, required this.isDark});

  final DashboardKpi kpi;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _KpiCard(
          title: '今日新增线索', value: kpi.todayNewClues.toString(),
          accentColor: AppTheme.primaryColor, isDark: isDark)),
        const SizedBox(width: 12),
        Expanded(child: _KpiCard(
          title: '本月跟进次数', value: kpi.monthFollowUps.toString(),
          accentColor: AppTheme.successColor, isDark: isDark)),
        const SizedBox(width: 12),
        Expanded(child: _KpiCard(
          title: '待跟进客户', value: kpi.pendingFollowUpCustomers.toString(),
          accentColor: AppTheme.warningColor, isDark: isDark)),
      ],
    );
  }
}


/// 单个 KPI 卡片
class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.accentColor,
    required this.isDark,
  });

  final String title;
  final String value;
  final Color accentColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = isDark ? Colors.white10 : AppTheme.dividerColor;
    final titleColor = isDark ? Colors.white70 : AppTheme.textSecondary;
    final valueColor = isDark ? Colors.white : AppTheme.textPrimary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: titleColor)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: valueColor)),
              const SizedBox(width: 6),
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: accentColor, shape: BoxShape.circle),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 快捷操作网格
class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({
    required this.actions,
    required this.onActionTap,
    required this.isDark,
  });

  final List<DashboardQuickAction> actions;
  final ValueChanged<DashboardQuickAction> onActionTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];
        final meta = _getActionMeta(action);
        return _QuickActionTile(
          icon: meta.$1, label: meta.$2, color: meta.$3,
          isDark: isDark, onTap: () => onActionTap(action),
        );
      },
    );
  }

  (IconData, String, Color) _getActionMeta(DashboardQuickAction action) {
    return switch (action) {
      DashboardQuickAction.newCustomer => 
          (Icons.person_add_alt_1, '新建客户', AppTheme.primaryColor),
      DashboardQuickAction.newClue => 
          (Icons.add_circle_outline, '新建线索', AppTheme.warningColor),
      DashboardQuickAction.newOpportunity => 
          (Icons.business_center_outlined, '新建商机', AppTheme.successColor),
      DashboardQuickAction.writeFollowUp => 
          (Icons.edit_note, '写跟进', AppTheme.primaryColor),
    };
  }
}


/// 快捷操作按钮
class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = isDark ? Colors.white10 : AppTheme.dividerColor;
    final labelColor = isDark ? Colors.white : AppTheme.textPrimary;

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, 
                      color: labelColor), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// 待办列表
class _TodoList extends StatelessWidget {
  const _TodoList({
    required this.todos,
    required this.isDark,
    required this.onTapTodo,
  });

  final List<DashboardTodo> todos;
  final bool isDark;
  final ValueChanged<DashboardTodo> onTapTodo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = isDark ? Colors.white10 : AppTheme.dividerColor;
    final subtitleColor = isDark ? Colors.white70 : AppTheme.textSecondary;

    if (todos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Text('今日暂无待办 🎉', style: TextStyle(color: subtitleColor)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          for (int i = 0; i < todos.length; i++) ...[
            _TodoTile(todo: todos[i], isDark: isDark, 
                onTap: () => onTapTodo(todos[i])),
            if (i != todos.length - 1)
              Divider(height: 1, thickness: 1, color: borderColor),
          ],
        ],
      ),
    );
  }
}


/// 待办事项行
class _TodoTile extends StatelessWidget {
  const _TodoTile({
    required this.todo,
    required this.isDark,
    required this.onTap,
  });

  final DashboardTodo todo;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? Colors.white : AppTheme.textPrimary;
    final subtitleColor = isDark ? Colors.white70 : AppTheme.textSecondary;

    final (icon, accent) = switch (todo.type) {
      DashboardTodoType.followUp => (Icons.schedule, AppTheme.warningColor),
      DashboardTodoType.customer => (Icons.people_outline, AppTheme.primaryColor),
      DashboardTodoType.clue => (Icons.lightbulb_outline, AppTheme.successColor),
      DashboardTodoType.other => (Icons.checklist, AppTheme.primaryColor),
    };

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(todo.title, style: TextStyle(
                      fontWeight: FontWeight.w600, color: titleColor)),
                  if (todo.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(todo.subtitle!, style: TextStyle(
                        fontSize: 12, color: subtitleColor)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(todo.dueTimeLabel, style: TextStyle(
                fontSize: 12, color: subtitleColor)),
          ],
        ),
      ),
    );
  }
}
