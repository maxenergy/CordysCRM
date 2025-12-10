import 'dart:convert';

import '../sources/local/app_database.dart';
import '../sources/local/dao/customer_dao.dart';
import '../sources/local/dao/sync_queue_dao.dart';
import '../sources/local/tables/tables.dart';

/// 客户实体（领域模型）
class CustomerEntity {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? owner;
  final String status;
  final SyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomerEntity({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.owner,
    required this.status,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 从数据库模型转换
  factory CustomerEntity.fromData(CustomerData data) {
    return CustomerEntity(
      id: data.id,
      name: data.name,
      phone: data.phone,
      email: data.email,
      owner: data.owner,
      status: data.status,
      syncStatus: data.syncStatus, // intEnum 已经是 SyncStatus 类型
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
    );
  }

  /// 转换为数据库模型
  CustomerData toData() {
    return CustomerData(
      id: id,
      name: name,
      phone: phone,
      email: email,
      owner: owner,
      status: status,
      syncStatus: syncStatus,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// 转换为 JSON（用于同步队列）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'owner': owner,
      'status': status,
    };
  }

  /// 复制并修改
  CustomerEntity copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? owner,
    String? status,
    SyncStatus? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      owner: owner ?? this.owner,
      status: status ?? this.status,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 本地客户数据仓库
///
/// 提供客户数据的本地存储和同步队列管理功能。
/// 作为业务逻辑层和数据访问层（DAO）之间的桥梁。
class LocalCustomerRepository {
  final AppDatabase _db;
  final CustomerDao _customerDao;
  final SyncQueueDao _syncQueueDao;

  LocalCustomerRepository({
    AppDatabase? database,
    CustomerDao? customerDao,
    SyncQueueDao? syncQueueDao,
  })  : _db = database ?? AppDatabase.instance,
        _customerDao = customerDao ?? CustomerDao(database ?? AppDatabase.instance),
        _syncQueueDao = syncQueueDao ?? SyncQueueDao(database ?? AppDatabase.instance);

  // ==================== 查询操作 ====================

  /// 获取所有客户
  Future<List<CustomerEntity>> getAllCustomers() async {
    final dataList = await _customerDao.getAllCustomers();
    return dataList.map(CustomerEntity.fromData).toList();
  }

  /// 根据ID获取客户
  Future<CustomerEntity?> getCustomerById(String id) async {
    final data = await _customerDao.getCustomerById(id);
    return data != null ? CustomerEntity.fromData(data) : null;
  }

  /// 根据同步状态获取客户
  Future<List<CustomerEntity>> getCustomersBySyncStatus(SyncStatus status) async {
    final dataList = await _customerDao.getCustomersBySyncStatus(status);
    return dataList.map(CustomerEntity.fromData).toList();
  }

  /// 获取待同步的客户
  Future<List<CustomerEntity>> getDirtyCustomers() async {
    return getCustomersBySyncStatus(SyncStatus.dirty);
  }

  /// 搜索客户
  Future<List<CustomerEntity>> searchCustomers(String keyword) async {
    final dataList = await _customerDao.searchCustomers(keyword);
    return dataList.map(CustomerEntity.fromData).toList();
  }

  /// 分页获取客户
  Future<List<CustomerEntity>> getCustomersPaginated({
    required int page,
    int pageSize = 20,
  }) async {
    final dataList = await _customerDao.getCustomersPaginated(
      limit: pageSize,
      offset: (page - 1) * pageSize,
    );
    return dataList.map(CustomerEntity.fromData).toList();
  }

  /// 获取客户总数
  Future<int> getCustomerCount() {
    return _customerDao.getCustomerCount();
  }

  /// 监听所有客户变化
  Stream<List<CustomerEntity>> watchAllCustomers() {
    return _customerDao.watchAllCustomers().map(
          (dataList) => dataList.map(CustomerEntity.fromData).toList(),
        );
  }

  /// 监听单个客户变化
  Stream<CustomerEntity?> watchCustomerById(String id) {
    return _customerDao.watchCustomerById(id).map(
          (data) => data != null ? CustomerEntity.fromData(data) : null,
        );
  }

  // ==================== 写入操作 ====================

  /// 创建客户（本地）
  ///
  /// 创建新客户并添加到同步队列，使用事务保证原子性
  Future<CustomerEntity> createCustomer(CustomerEntity customer) async {
    final now = DateTime.now();
    final newCustomer = customer.copyWith(
      syncStatus: SyncStatus.dirty,
      createdAt: now,
      updatedAt: now,
    );

    // 使用事务保证原子性
    await _db.transaction(() async {
      // 保存到本地数据库
      await _customerDao.upsertCustomer(newCustomer.toData());

      // 添加到同步队列
      await _syncQueueDao.addSyncItem(
        entityType: 'customers',
        entityId: newCustomer.id,
        operation: SyncOperation.create,
        payload: jsonEncode(newCustomer.toJson()),
      );
    });

    return newCustomer;
  }

  /// 更新客户（本地）
  ///
  /// 更新客户信息并添加到同步队列，使用事务保证原子性
  Future<CustomerEntity> updateCustomer(CustomerEntity customer) async {
    final updatedCustomer = customer.copyWith(
      syncStatus: SyncStatus.dirty,
      updatedAt: DateTime.now(),
    );

    // 使用事务保证原子性
    await _db.transaction(() async {
      // 保存到本地数据库
      await _customerDao.upsertCustomer(updatedCustomer.toData());

      // 添加到同步队列
      await _syncQueueDao.addSyncItem(
        entityType: 'customers',
        entityId: updatedCustomer.id,
        operation: SyncOperation.update,
        payload: jsonEncode(updatedCustomer.toJson()),
      );
    });

    return updatedCustomer;
  }

  /// 删除客户（本地）
  ///
  /// 删除客户并添加到同步队列，使用事务保证原子性
  Future<void> deleteCustomer(String id) async {
    // 使用事务保证原子性
    await _db.transaction(() async {
      // 添加到同步队列（先添加，确保即使删除失败也能同步）
      await _syncQueueDao.addSyncItem(
        entityType: 'customers',
        entityId: id,
        operation: SyncOperation.delete,
        payload: jsonEncode({'id': id}),
      );

      // 从本地数据库删除
      await _customerDao.deleteCustomer(id);
    });
  }

  // ==================== 同步操作 ====================

  /// 从服务器同步客户数据
  ///
  /// 将服务器数据保存到本地，标记为已同步
  Future<void> syncFromServer(List<CustomerEntity> customers) async {
    final dataList = customers
        .map((c) => c.copyWith(syncStatus: SyncStatus.synced).toData())
        .toList();
    await _customerDao.upsertCustomers(dataList);
  }

  /// 标记客户为已同步
  Future<void> markAsSynced(String id) async {
    await _customerDao.markAsSynced(id);
    // 删除该客户的同步队列项
    await _syncQueueDao.deleteSyncItemsByEntity('customers', id);
  }

  /// 批量标记为已同步
  Future<void> markAllAsSynced(List<String> ids) async {
    for (final id in ids) {
      await markAsSynced(id);
    }
  }

  // ==================== 同步队列操作 ====================

  /// 获取待同步项数量
  Future<int> getPendingSyncCount() {
    return _syncQueueDao.getPendingCount();
  }

  /// 监听待同步项数量
  Stream<int> watchPendingSyncCount() {
    return _syncQueueDao.watchPendingCount();
  }
}
