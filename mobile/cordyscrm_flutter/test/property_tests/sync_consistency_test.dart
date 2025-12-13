import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
// ignore: unused_import
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';

import 'package:cordyscrm_flutter/data/sources/local/app_database.dart';
import 'package:cordyscrm_flutter/data/sources/local/tables/tables.dart';
import 'package:cordyscrm_flutter/data/sources/local/dao/sync_queue_dao.dart';
import 'package:cordyscrm_flutter/data/repositories/local_customer_repository.dart';

/// **Feature: crm-mobile-enterprise-ai, Property 4: 离线同步数据一致性**
/// **Validates: Requirements 1.7**
///
/// For any 本地变更操作，在设备恢复在线后，服务器应该收到与本地变更完全相同的数据，
/// 且变更顺序应该保持一致。
void main() {
  late AppDatabase database;
  late LocalCustomerRepository repository;
  late SyncQueueDao syncQueueDao;
  final random = Random();

  /// 生成随机字符串
  String randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// 生成随机客户实体
  CustomerEntity generateRandomCustomer() {
    final now = DateTime.now();
    return CustomerEntity(
      id: randomString(32),
      name: '${randomString(4)}公司',
      phone: '1${random.nextInt(9) + 3}${List.generate(9, (_) => random.nextInt(10)).join()}',
      email: '${randomString(8)}@${randomString(5)}.com',
      owner: randomString(8),
      status: ['active', 'inactive', 'pending'][random.nextInt(3)],
      syncStatus: SyncStatus.synced,
      createdAt: now,
      updatedAt: now,
    );
  }

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LocalCustomerRepository(database: database);
    syncQueueDao = SyncQueueDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('Property 4: 离线同步数据一致性', () {
    /// Property Test: 创建操作应该被记录到同步队列
    test('should record create operations in sync queue', () async {
      for (var i = 0; i < 50; i++) {
        await database.clearAllData();

        final customer = generateRandomCustomer();

        // 创建客户
        final created = await repository.createCustomer(customer);

        // 检查同步队列
        final pendingItems = await syncQueueDao.getPendingItems();
        expect(pendingItems.length, equals(1));

        final syncItem = pendingItems.first;
        expect(syncItem.entityType, equals('customers'));
        expect(syncItem.entityId, equals(created.id));
        expect(syncItem.operation, equals(SyncOperation.create));

        // 验证 payload 包含正确的数据
        final payload = jsonDecode(syncItem.payload) as Map<String, dynamic>;
        expect(payload['name'], equals(customer.name));
        expect(payload['phone'], equals(customer.phone));
        expect(payload['email'], equals(customer.email));
      }
    });

    /// Property Test: 更新操作应该被记录到同步队列
    test('should record update operations in sync queue', () async {
      for (var i = 0; i < 50; i++) {
        await database.clearAllData();

        final customer = generateRandomCustomer();

        // 创建客户
        final created = await repository.createCustomer(customer);

        // 标记为已同步（模拟已同步到服务器）
        await repository.markAsSynced(created.id);

        // 更新客户
        final newName = '${randomString(4)}更新公司';
        final updated = created.copyWith(name: newName);
        await repository.updateCustomer(updated);

        // 检查同步队列
        final pendingItems = await syncQueueDao.getPendingItems();
        expect(pendingItems.length, equals(1));

        final syncItem = pendingItems.first;
        expect(syncItem.entityType, equals('customers'));
        expect(syncItem.entityId, equals(created.id));
        expect(syncItem.operation, equals(SyncOperation.update));

        // 验证 payload 包含更新后的数据
        final payload = jsonDecode(syncItem.payload) as Map<String, dynamic>;
        expect(payload['name'], equals(newName));
      }
    });

    /// Property Test: 删除操作应该被记录到同步队列
    test('should record delete operations in sync queue', () async {
      for (var i = 0; i < 50; i++) {
        await database.clearAllData();

        final customer = generateRandomCustomer();

        // 创建客户
        final created = await repository.createCustomer(customer);

        // 标记为已同步
        await repository.markAsSynced(created.id);

        // 删除客户
        await repository.deleteCustomer(created.id);

        // 检查同步队列
        final pendingItems = await syncQueueDao.getPendingItems();
        expect(pendingItems.length, equals(1));

        final syncItem = pendingItems.first;
        expect(syncItem.entityType, equals('customers'));
        expect(syncItem.entityId, equals(created.id));
        expect(syncItem.operation, equals(SyncOperation.delete));
      }
    });

    /// Property Test: 同步队列应该保持操作顺序
    test('should maintain operation order in sync queue', () async {
      for (var iteration = 0; iteration < 20; iteration++) {
        await database.clearAllData();

        // 创建多个客户
        final customers = <CustomerEntity>[];
        final operationCount = random.nextInt(6) + 5; // 5-10 个操作

        for (var i = 0; i < operationCount; i++) {
          final customer = generateRandomCustomer();
          final created = await repository.createCustomer(customer);
          customers.add(created);
          // 添加小延迟确保时间戳不同
          await Future.delayed(const Duration(milliseconds: 1));
        }

        // 检查同步队列顺序
        final pendingItems = await syncQueueDao.getPendingItems();
        expect(pendingItems.length, equals(operationCount));

        // 验证顺序（按创建时间排序）
        for (var i = 0; i < pendingItems.length - 1; i++) {
          expect(
            pendingItems[i].createdAt.isBefore(pendingItems[i + 1].createdAt) ||
                pendingItems[i].createdAt.isAtSameMomentAs(pendingItems[i + 1].createdAt),
            isTrue,
            reason: 'Sync queue items should be ordered by creation time',
          );
        }
      }
    });

    /// Property Test: 同步完成后队列应该被清空
    test('should clear sync queue after marking as synced', () async {
      for (var i = 0; i < 30; i++) {
        await database.clearAllData();

        final customer = generateRandomCustomer();

        // 创建客户
        final created = await repository.createCustomer(customer);

        // 验证有待同步项
        var pendingCount = await repository.getPendingSyncCount();
        expect(pendingCount, equals(1));

        // 标记为已同步
        await repository.markAsSynced(created.id);

        // 验证队列已清空
        pendingCount = await repository.getPendingSyncCount();
        expect(pendingCount, equals(0));
      }
    });

    /// Property Test: 同步队列 payload 应该与本地数据一致
    test('should have consistent payload with local data', () async {
      for (var i = 0; i < 50; i++) {
        await database.clearAllData();

        final customer = generateRandomCustomer();

        // 创建客户
        final created = await repository.createCustomer(customer);

        // 获取本地数据
        final localData = await repository.getCustomerById(created.id);
        expect(localData, isNotNull);

        // 获取同步队列中的 payload
        final pendingItems = await syncQueueDao.getPendingItems();
        expect(pendingItems.length, equals(1));

        final payload = jsonDecode(pendingItems.first.payload) as Map<String, dynamic>;

        // 验证 payload 与本地数据一致
        expect(payload['id'], equals(localData!.id));
        expect(payload['name'], equals(localData.name));
        expect(payload['phone'], equals(localData.phone));
        expect(payload['email'], equals(localData.email));
        expect(payload['owner'], equals(localData.owner));
        expect(payload['status'], equals(localData.status));
      }
    });

    /// Property Test: 批量同步应该正确更新所有记录
    test('should correctly sync multiple records from server', () async {
      for (var iteration = 0; iteration < 20; iteration++) {
        await database.clearAllData();

        // 模拟从服务器同步的数据
        final serverCustomers = List.generate(
          random.nextInt(16) + 5, // 5-20 个客户
          (_) => generateRandomCustomer(),
        );

        // 同步到本地
        await repository.syncFromServer(serverCustomers);

        // 验证所有数据都已保存
        final localCustomers = await repository.getAllCustomers();
        expect(localCustomers.length, equals(serverCustomers.length));

        // 验证每条数据的内容
        for (final serverCustomer in serverCustomers) {
          final localCustomer = localCustomers.firstWhere(
            (c) => c.id == serverCustomer.id,
            orElse: () => throw Exception('Customer ${serverCustomer.id} not found'),
          );

          expect(localCustomer.name, equals(serverCustomer.name));
          expect(localCustomer.phone, equals(serverCustomer.phone));
          expect(localCustomer.email, equals(serverCustomer.email));
          expect(localCustomer.syncStatus, equals(SyncStatus.synced));
        }
      }
    });
  });
}
