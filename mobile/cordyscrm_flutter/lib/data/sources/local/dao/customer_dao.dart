import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/tables.dart';

part 'customer_dao.g.dart';

/// 客户数据访问对象
@DriftAccessor(tables: [Customers])
class CustomerDao extends DatabaseAccessor<AppDatabase>
    with _$CustomerDaoMixin {
  CustomerDao(super.db);

  /// 获取所有客户
  Future<List<CustomerData>> getAllCustomers() => select(customers).get();

  /// 根据ID获取客户
  Future<CustomerData?> getCustomerById(String id) {
    return (select(customers)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  /// 根据同步状态查询客户
  Future<List<CustomerData>> getCustomersBySyncStatus(SyncStatus status) {
    return (select(customers)..where((c) => c.syncStatus.equalsValue(status)))
        .get();
  }

  /// 获取待同步的客户（dirty状态）
  Future<List<CustomerData>> getDirtyCustomers() {
    return getCustomersBySyncStatus(SyncStatus.dirty);
  }

  /// 监听所有客户变化
  Stream<List<CustomerData>> watchAllCustomers() => select(customers).watch();

  /// 监听单个客户变化
  Stream<CustomerData?> watchCustomerById(String id) {
    return (select(customers)..where((c) => c.id.equals(id)))
        .watchSingleOrNull();
  }

  /// 插入或更新客户
  Future<void> upsertCustomer(CustomerData customer) {
    return into(customers).insertOnConflictUpdate(customer);
  }

  /// 批量插入或更新客户
  Future<void> upsertCustomers(List<CustomerData> customerList) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(customers, customerList);
    });
  }

  /// 删除客户
  Future<int> deleteCustomer(String id) {
    return (delete(customers)..where((c) => c.id.equals(id))).go();
  }

  /// 批量删除客户（用于同步删除操作）
  Future<int> deleteAllByIds(List<String> ids) async {
    if (ids.isEmpty) return 0;
    return (delete(customers)..where((c) => c.id.isIn(ids))).go();
  }

  /// 更新客户同步状态
  Future<int> updateSyncStatus(String id, SyncStatus status) {
    return (update(customers)..where((c) => c.id.equals(id))).write(
      CustomersCompanion(
        syncStatus: Value(status),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 标记客户为已同步
  Future<int> markAsSynced(String id) {
    return updateSyncStatus(id, SyncStatus.synced);
  }

  /// 标记客户为待同步
  Future<int> markAsDirty(String id) {
    return updateSyncStatus(id, SyncStatus.dirty);
  }

  /// 搜索客户（按名称或电话）
  Future<List<CustomerData>> searchCustomers(String keyword) {
    return (select(customers)
          ..where((c) =>
              c.name.like('%$keyword%') | c.phone.like('%$keyword%')))
        .get();
  }

  /// 分页获取客户
  Future<List<CustomerData>> getCustomersPaginated({
    required int limit,
    required int offset,
  }) {
    return (select(customers)
          ..orderBy([(c) => OrderingTerm.desc(c.updatedAt)])
          ..limit(limit, offset: offset))
        .get();
  }

  /// 获取客户总数
  Future<int> getCustomerCount() async {
    final count = customers.id.count();
    final query = selectOnly(customers)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }
}
