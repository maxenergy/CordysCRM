import '../entities/customer.dart';

/// 客户仓库接口
abstract class CustomerRepository {
  /// 获取客户列表（分页）
  Future<PagedResponse<Customer>> getCustomers({
    required int page,
    required int pageSize,
    CustomerQuery? query,
  });

  /// 根据 ID 获取客户
  Future<Customer?> getCustomerById(String id);

  /// 创建客户
  Future<Customer> createCustomer(Customer customer);

  /// 更新客户
  Future<Customer> updateCustomer(Customer customer);

  /// 删除客户
  Future<void> deleteCustomer(String id);

  /// 搜索客户
  Future<List<Customer>> searchCustomers(String keyword);
}
