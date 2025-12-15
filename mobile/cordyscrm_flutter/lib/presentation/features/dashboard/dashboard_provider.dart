import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dashboard 快捷操作枚举
enum DashboardQuickAction {
  newCustomer,
  newClue,
  newOpportunity,
  writeFollowUp,
}

/// Dashboard 待办类型
enum DashboardTodoType {
  followUp,
  customer,
  clue,
  other,
}

/// KPI 数据模型
@immutable
class DashboardKpi {
  const DashboardKpi({
    required this.todayNewClues,
    required this.monthFollowUps,
    required this.pendingFollowUpCustomers,
  });

  final int todayNewClues;
  final int monthFollowUps;
  final int pendingFollowUpCustomers;
}

/// 待办事项数据模型
@immutable
class DashboardTodo {
  const DashboardTodo({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    required this.dueAt,
    this.relatedId,
  });

  final String id;
  final DashboardTodoType type;
  final String title;
  final String? subtitle;
  final DateTime dueAt;
  final String? relatedId;

  /// 格式化时间标签
  String get dueTimeLabel {
    final h = dueAt.hour.toString().padLeft(2, '0');
    final m = dueAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// Dashboard 完整数据模型
@immutable
class DashboardData {
  const DashboardData({
    required this.kpi,
    required this.quickActions,
    required this.todos,
    required this.generatedAt,
  });

  final DashboardKpi kpi;
  final List<DashboardQuickAction> quickActions;
  final List<DashboardTodo> todos;
  final DateTime generatedAt;
}

/// Dashboard 数据源抽象
abstract class DashboardRepository {
  Future<DashboardData> fetchDashboard();
}

/// 模拟数据仓库实现
class MockDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardData> fetchDashboard() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final now = DateTime.now();
    final today9 = DateTime(now.year, now.month, now.day, 9, 0);
    final today14 = DateTime(now.year, now.month, now.day, 14, 0);
    final today17 = DateTime(now.year, now.month, now.day, 17, 30);

    return DashboardData(
      generatedAt: now,
      kpi: const DashboardKpi(
        todayNewClues: 6,
        monthFollowUps: 42,
        pendingFollowUpCustomers: 9,
      ),
      quickActions: const [
        DashboardQuickAction.newCustomer,
        DashboardQuickAction.newClue,
        DashboardQuickAction.newOpportunity,
        DashboardQuickAction.writeFollowUp,
      ],
      todos: [
        DashboardTodo(
          id: 'todo_1',
          type: DashboardTodoType.followUp,
          title: '回访：张三（意向客户）',
          subtitle: '上次沟通：报价与合同条款',
          dueAt: today9,
        ),
        DashboardTodo(
          id: 'todo_2',
          type: DashboardTodoType.customer,
          title: '跟进：深圳某科技有限公司',
          subtitle: '确认关键联系人与采购流程',
          dueAt: today14,
        ),
        DashboardTodo(
          id: 'todo_3',
          type: DashboardTodoType.clue,
          title: '处理线索：官网表单新增',
          subtitle: '来源：官网 / 产品咨询',
          dueAt: today17,
        ),
      ],
    );
  }
}

/// Dashboard Repository Provider
final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return MockDashboardRepository();
});

/// Dashboard 数据 Provider
final dashboardDataProvider = FutureProvider<DashboardData>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.fetchDashboard();
});
