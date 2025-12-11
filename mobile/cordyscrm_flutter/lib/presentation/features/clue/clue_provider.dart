import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../domain/entities/clue.dart';
import '../../../domain/repositories/clue_repository.dart';
import '../../../data/repositories/clue_repository_impl.dart';

// ==================== Repository Provider ====================

/// 线索仓库 Provider
final clueRepositoryProvider = Provider<ClueRepository>((ref) {
  return ClueRepositoryImpl();
});

// ==================== Filter State ====================

/// 线索筛选条件 Provider
final clueFilterProvider = StateProvider<ClueQuery>((ref) {
  return const ClueQuery();
});

// ==================== Paging Controller ====================

/// 分页控制器 Provider
final cluePagingControllerProvider =
    Provider.autoDispose<PagingController<int, Clue>>((ref) {
  const pageSize = 20;
  final repo = ref.watch(clueRepositoryProvider);
  final query = ref.watch(clueFilterProvider);

  final pagingController = PagingController<int, Clue>(firstPageKey: 1);

  Future<void> fetchPage(int pageKey) async {
    try {
      final pagedResponse = await repo.getClues(
        page: pageKey,
        pageSize: pageSize,
        query: query,
      );

      final isLastPage = !pagedResponse.hasMore;
      if (isLastPage) {
        pagingController.appendLastPage(pagedResponse.items);
      } else {
        pagingController.appendPage(pagedResponse.items, pageKey + 1);
      }
    } catch (error) {
      pagingController.error = error;
    }
  }

  pagingController.addPageRequestListener(fetchPage);
  ref.onDispose(() => pagingController.dispose());

  return pagingController;
});


// ==================== Clue Detail ====================

/// 线索详情 Provider
final clueDetailProvider =
    FutureProvider.autoDispose.family<Clue?, String>((ref, id) async {
  final repo = ref.watch(clueRepositoryProvider);
  return repo.getClueById(id);
});

// ==================== Clue Form ====================

/// 线索表单状态
enum ClueFormStatus { initial, loading, success, error }

/// 线索表单状态类
class ClueFormState {
  const ClueFormState({
    this.status = ClueFormStatus.initial,
    this.errorMessage,
  });

  final ClueFormStatus status;
  final String? errorMessage;

  ClueFormState copyWith({
    ClueFormStatus? status,
    String? errorMessage,
  }) {
    return ClueFormState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// 线索表单 Notifier
class ClueFormNotifier extends StateNotifier<ClueFormState> {
  ClueFormNotifier(this._repository) : super(const ClueFormState());

  final ClueRepository _repository;

  /// 保存线索（创建或更新）
  Future<bool> saveClue(Clue clue, {bool isNew = false}) async {
    state = state.copyWith(status: ClueFormStatus.loading);

    try {
      if (isNew) {
        await _repository.createClue(clue);
      } else {
        await _repository.updateClue(clue);
      }
      state = state.copyWith(status: ClueFormStatus.success);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: ClueFormStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// 转化为客户
  Future<String?> convertToCustomer(String clueId) async {
    state = state.copyWith(status: ClueFormStatus.loading);

    try {
      final customerId = await _repository.convertToCustomer(clueId);
      state = state.copyWith(status: ClueFormStatus.success);
      return customerId;
    } catch (e) {
      state = state.copyWith(
        status: ClueFormStatus.error,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  void reset() {
    state = const ClueFormState();
  }
}

/// 线索表单 Provider
final clueFormProvider =
    StateNotifierProvider.autoDispose<ClueFormNotifier, ClueFormState>((ref) {
  final repository = ref.watch(clueRepositoryProvider);
  return ClueFormNotifier(repository);
});

// ==================== Status Options ====================

/// 线索状态选项
const clueStatusOptions = ['全部', '新线索', '跟进中', '已转化', '无效'];

/// 线索来源选项
const clueSourceOptions = ['全部', '网站注册', '电话咨询', '展会', '转介绍', '广告投放'];

/// 负责人选项
const clueOwnerOptions = ['全部', '张三', '李四', '王五', '赵六'];
