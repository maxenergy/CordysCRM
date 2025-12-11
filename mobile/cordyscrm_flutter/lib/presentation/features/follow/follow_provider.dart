import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/follow_record.dart';
import '../../../domain/repositories/follow_record_repository.dart';
import '../../../data/repositories/follow_record_repository_impl.dart';

// ==================== Repository Provider ====================

final followRecordRepositoryProvider = Provider<FollowRecordRepository>((ref) {
  return FollowRecordRepositoryImpl();
});

// ==================== Follow Records by Customer ====================

final customerFollowRecordsProvider =
    FutureProvider.autoDispose.family<List<FollowRecord>, String>((ref, customerId) async {
  final repo = ref.watch(followRecordRepositoryProvider);
  return repo.getFollowRecordsByCustomerId(customerId);
});

// ==================== Follow Records by Clue ====================

final clueFollowRecordsProvider =
    FutureProvider.autoDispose.family<List<FollowRecord>, String>((ref, clueId) async {
  final repo = ref.watch(followRecordRepositoryProvider);
  return repo.getFollowRecordsByClueId(clueId);
});

// ==================== Follow Form ====================

enum FollowFormStatus { initial, loading, success, error }

class FollowFormState {
  const FollowFormState({
    this.status = FollowFormStatus.initial,
    this.errorMessage,
  });

  final FollowFormStatus status;
  final String? errorMessage;

  FollowFormState copyWith({
    FollowFormStatus? status,
    String? errorMessage,
  }) {
    return FollowFormState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class FollowFormNotifier extends StateNotifier<FollowFormState> {
  FollowFormNotifier(this._repository) : super(const FollowFormState());

  final FollowRecordRepository _repository;

  Future<bool> createFollowRecord(FollowRecord record) async {
    state = state.copyWith(status: FollowFormStatus.loading);

    try {
      await _repository.createFollowRecord(record);
      state = state.copyWith(status: FollowFormStatus.success);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: FollowFormStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  void reset() {
    state = const FollowFormState();
  }
}

final followFormProvider =
    StateNotifierProvider.autoDispose<FollowFormNotifier, FollowFormState>((ref) {
  final repository = ref.watch(followRecordRepositoryProvider);
  return FollowFormNotifier(repository);
});

// ==================== Follow Type Options ====================

const followTypeOptions = [
  (FollowRecord.typePhone, '电话', 'phone'),
  (FollowRecord.typeVisit, '拜访', 'place'),
  (FollowRecord.typeWechat, '微信', 'chat'),
  (FollowRecord.typeEmail, '邮件', 'email'),
  (FollowRecord.typeOther, '其他', 'note'),
];
