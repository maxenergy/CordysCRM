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
  void _initMockData() {
    if (_mockCustomers.isNotEmpty) return;

    const statuses = ['潜在客户', '意向客户', '成交客户', '流失客户'];
    const owners = ['张三', '李四', '王五', '赵六'];
    const industries = ['IT/互联网', '金融', '制造业', '零售', '教育'];
    const sources = ['线上推广', '客户转介绍', '展会', '电话营销', '官网'];
    const companyTypes = ['科技', '贸易', '咨询', '制造', '服务'];

    for (var i = 0; i < 100; i++) {
      _mockCustomers.add(Customer(
        id: 'cust_${i + 1}',
        name: '示例${companyTypes[i % companyTypes.length]}公司 ${i + 1}',
        contactPerson: '联系人 ${i + 1}',
        phone: '138${_random.nextInt(90000000) + 10000000}',
        email: 'contact${i + 1}@example.com',
        owner: owners[i % owners.length],
        status: statuses[i % statuses.length],
        industry: industries[i % industries.length],
        source: sources[i % sources.length],
        address: '示例城市示例街道 ${i + 1} 号',
        lastFollowUpAt: DateTime.now().subtract(Duration(days: _random.nextInt(30))),
        createdAt: DateTime.now().subtract(Duration(days: _random.nextInt(365))),
        updatedAt: DateTime.now(),
      ));
    }
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
