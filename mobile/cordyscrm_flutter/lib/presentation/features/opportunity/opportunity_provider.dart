import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../core/config/app_perf_config.dart';
import '../../../domain/entities/opportunity.dart';
import '../../../domain/repositories/opportunity_repository.dart';
import '../../../data/repositories/opportunity_repository_impl.dart';

// ==================== Repository Provider ====================

final opportunityRepositoryProvider = Provider<OpportunityRepository>((ref) {
  return OpportunityRepositoryImpl();
});

// ==================== Filter State ====================

final opportunityFilterProvider = StateProvider<OpportunityQuery>((ref) {
  return const OpportunityQuery();
});

// ==================== Paging Controller ====================

final opportunityPagingControllerProvider =
    Provider.autoDispose<PagingController<int, Opportunity>>((ref) {
  final pageSize = ref.watch(appPerfConfigProvider).pageSize;
  final repo = ref.watch(opportunityRepositoryProvider);
  final query = ref.watch(opportunityFilterProvider);

  final pagingController = PagingController<int, Opportunity>(firstPageKey: 1);

  Future<void> fetchPage(int pageKey) async {
    try {
      final pagedResponse = await repo.getOpportunities(
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

// ==================== Opportunity Detail ====================

final opportunityDetailProvider =
    FutureProvider.autoDispose.family<Opportunity?, String>((ref, id) async {
  final repo = ref.watch(opportunityRepositoryProvider);
  return repo.getOpportunityById(id);
});


// ==================== Opportunity Form ====================

enum OpportunityFormStatus { initial, loading, success, error }

class OpportunityFormState {
  const OpportunityFormState({
    this.status = OpportunityFormStatus.initial,
    this.errorMessage,
  });

  final OpportunityFormStatus status;
  final String? errorMessage;

  OpportunityFormState copyWith({
    OpportunityFormStatus? status,
    String? errorMessage,
  }) {
    return OpportunityFormState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class OpportunityFormNotifier extends StateNotifier<OpportunityFormState> {
  OpportunityFormNotifier(this._repository) : super(const OpportunityFormState());

  final OpportunityRepository _repository;

  Future<bool> saveOpportunity(Opportunity opportunity, {bool isNew = false}) async {
    state = state.copyWith(status: OpportunityFormStatus.loading);

    try {
      if (isNew) {
        await _repository.createOpportunity(opportunity);
      } else {
        await _repository.updateOpportunity(opportunity);
      }
      state = state.copyWith(status: OpportunityFormStatus.success);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: OpportunityFormStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> advanceStage(String opportunityId, String newStage) async {
    state = state.copyWith(status: OpportunityFormStatus.loading);

    try {
      await _repository.advanceStage(opportunityId, newStage);
      state = state.copyWith(status: OpportunityFormStatus.success);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: OpportunityFormStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  void reset() {
    state = const OpportunityFormState();
  }
}

final opportunityFormProvider =
    StateNotifierProvider.autoDispose<OpportunityFormNotifier, OpportunityFormState>((ref) {
  final repository = ref.watch(opportunityRepositoryProvider);
  return OpportunityFormNotifier(repository);
});

// ==================== Status Options ====================

const opportunityStageOptions = ['全部', '初步接触', '需求确认', '方案报价', '商务谈判', '赢单', '输单'];
/// 负责人选项（仅保留"全部"，实际应从 API 获取）
const opportunityOwnerOptions = ['全部'];
