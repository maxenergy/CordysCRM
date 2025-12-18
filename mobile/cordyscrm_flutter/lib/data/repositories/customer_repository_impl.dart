import 'dart:math';

import '../../domain/entities/customer.dart';
import '../../domain/repositories/customer_repository.dart';

/// 客户仓库实现（Mock 版本）
/// 
/// TODO: 后续替换为真实 API 调用
class CustomerRepositoryImpl implements CustomerRepository {
  CustomerRepositoryImpl() {
    _initMockData();
  }

  final List<Customer> _mockCustomers = [];
  final Random _random = Random();

  /// 初始化 Mock 数据
  /// 注意：已清空模拟数据，客户数据应通过企业导入功能创建
  void _initMockData() {
    // 不再生成模拟数据，保持空列表
    // 客户数据应通过企业搜索 -> 导入流程创建
  }

  @override
  Future<PagedResponse<Customer>> getCustomers({
    required int page,
    required int pageSize,
    CustomerQuery? query,
  }) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 500));

    var filteredCustomers = List<Customer>.from(_mockCustomers);

    // 应用筛选条件
    if (query != null) {
      // 搜索
      if (query.search != null && query.search!.isNotEmpty) {
        final searchLower = query.search!.toLowerCase();
        filteredCustomers = filteredCustomers.where((c) {
          return c.name.toLowerCase().contains(searchLower) ||
              (c.contactPerson?.toLowerCase().contains(searchLower) ?? false) ||
              (c.phone?.contains(query.search!) ?? false);
        }).toList();
      }

      // 状态筛选
      if (query.status != null && query.status != '全部') {
        filteredCustomers =
            filteredCustomers.where((c) => c.status == query.status).toList();
      }

      // 负责人筛选
      if (query.owner != null && query.owner != '全部') {
        filteredCustomers =
            filteredCustomers.where((c) => c.owner == query.owner).toList();
      }

      // 创建时间筛选
      if (query.startDate != null) {
        filteredCustomers = filteredCustomers
            .where((c) => !c.createdAt.isBefore(query.startDate!))
            .toList();
      }
      if (query.endDate != null) {
        final endOfDay = query.endDate!.add(const Duration(days: 1));
        filteredCustomers = filteredCustomers
            .where((c) => c.createdAt.isBefore(endOfDay))
            .toList();
      }
    }

    // 分页
    final total = filteredCustomers.length;
    final start = (page - 1) * pageSize;
    final end = min(start + pageSize, total);
    final items = start < total ? filteredCustomers.sublist(start, end) : <Customer>[];

    return PagedResponse(
      items: items,
      total: total,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<Customer?> getCustomerById(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      return _mockCustomers.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<Customer> createCustomer(Customer customer) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final newCustomer = customer.copyWith(
      id: 'cust_${_mockCustomers.length + 1}',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _mockCustomers.insert(0, newCustomer);
    return newCustomer;
  }

  @override
  Future<Customer> updateCustomer(Customer customer) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final index = _mockCustomers.indexWhere((c) => c.id == customer.id);
    if (index == -1) {
      throw Exception('客户不存在');
    }
    
    final updatedCustomer = customer.copyWith(updatedAt: DateTime.now());
    _mockCustomers[index] = updatedCustomer;
    return updatedCustomer;
  }

  @override
  Future<void> deleteCustomer(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _mockCustomers.removeWhere((c) => c.id == id);
  }

  @override
  Future<List<Customer>> searchCustomers(String keyword) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (keyword.isEmpty) return [];
    
    final keywordLower = keyword.toLowerCase();
    return _mockCustomers.where((c) {
      return c.name.toLowerCase().contains(keywordLower) ||
          (c.contactPerson?.toLowerCase().contains(keywordLower) ?? false);
    }).take(10).toList();
  }
}
