import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../domain/entities/customer.dart';
import '../../../domain/repositories/customer_repository.dart';
import '../../../data/repositories/customer_repository_impl.dart';

// ==================== Repository Provider ====================

/// 客户仓库 Provider
final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepositoryImpl();
});

// ==================== Filter State ====================

/// 客户筛选条件 Provider
final customerFilterProvider = StateProvider<CustomerQuery>((ref) {
  return const CustomerQuery();
});

// ==================== Paging Controller ====================

/// 分页控制器 Provider
/// 
/// 使用 autoDispose 确保页面销毁时自动清理资源
final customerPagingControllerProvider =
    Provider.autoDispose<PagingController<int, Customer>>((ref) {
  const pageSize = 20;
  final repo = ref.watch(customerRepositoryProvider);
  final query = ref.watch(customerFilterProvider);

  final pagingController = PagingController<int, Customer>(firstPageKey: 1);

  Future<void> fetchPage(int pageKey) async {
    try {
      final pagedResponse = await repo.getCustomers(
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

  // 当 Provider 被销毁时，清理分页控制器
  ref.onDispose(() => pagingController.dispose());

  return pagingController;
});

// ==================== Customer Detail ====================

/// 客户详情 Provider
/// 
/// 使用 family 支持按 ID 获取不同客户
final customerDetailProvider =
    FutureProvider.autoDispose.family<Customer?, String>((ref, id) async {
  final repo = ref.watch(customerRepositoryProvider);
  return repo.getCustomerById(id);
});

// ==================== Customer Form ====================

/// 客户表单状态
enum CustomerFormStatus {
  initial,
  loading,
  success,
  error,
}

/// 客户表单状态类
class CustomerFormState {
  const CustomerFormState({
    this.status = CustomerFormStatus.initial,
    this.errorMessage,
  });

  final CustomerFormStatus status;
  final String? errorMessage;

  CustomerFormState copyWith({
    CustomerFormStatus? status,
    String? errorMessage,
  }) {
    return CustomerFormState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// 客户表单 Notifier
class CustomerFormNotifier extends StateNotifier<CustomerFormState> {
  CustomerFormNotifier(this._repository) : super(const CustomerFormState());

  final CustomerRepository _repository;

  /// 保存客户（创建或更新）
  Future<bool> saveCustomer(Customer customer, {bool isNew = false}) async {
    state = state.copyWith(status: CustomerFormStatus.loading);

    try {
      if (isNew) {
        await _repository.createCustomer(customer);
      } else {
        await _repository.updateCustomer(customer);
      }
      state = state.copyWith(status: CustomerFormStatus.success);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: CustomerFormStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// 重置状态
  void reset() {
    state = const CustomerFormState();
  }
}

/// 客户表单 Provider
final customerFormProvider =
    StateNotifierProvider.autoDispose<CustomerFormNotifier, CustomerFormState>(
        (ref) {
  final repository = ref.watch(customerRepositoryProvider);
  return CustomerFormNotifier(repository);
});

// ==================== Customer Status Options ====================

/// 客户状态选项
const customerStatusOptions = [
  '全部',
  '潜在客户',
  '意向客户',
  '成交客户',
  '流失客户',
];

/// 负责人选项（实际应从 API 获取）
const customerOwnerOptions = [
  '全部',
  '张三',
  '李四',
  '王五',
  '赵六',
];
