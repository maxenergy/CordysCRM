import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';

import 'package:cordyscrm_flutter/data/sources/local/app_database.dart';
import 'package:cordyscrm_flutter/data/sources/local/tables/tables.dart';
import 'package:cordyscrm_flutter/data/repositories/local_customer_repository.dart';

/// **Feature: crm-mobile-enterprise-ai, Property 3: 离线数据缓存完整性**
/// **Validates: Requirements 1.6**
///
/// For any 用户相关的客户、线索和跟进记录，在离线状态下应该能够从本地存储完整读取，
/// 且数据与最后一次同步时的服务器数据一致。
void main() {
  late AppDatabase database;
  late LocalCustomerRepository repository;
  final random = Random();

  /// 生成随机字符串
  String randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// 生成随机手机号
  String randomPhone() {
    return '1${random.nextInt(9) + 3}${List.generate(9, (_) => random.nextInt(10)).join()}';
  }

  /// 生成随机邮箱
  String randomEmail() {
    return '${randomString(8)}@${randomString(5)}.com';
  }

  /// 生成随机客户实体
  CustomerEntity generateRandomCustomer() {
    final now = DateTime.now();
    return CustomerEntity(
      id: randomString(32),
      name: '${randomString(4)}公司',
      phone: randomPhone(),
      email: randomEmail(),
      owner: randomString(8),
      status: ['active', 'inactive', 'pending'][random.nextInt(3)],
      syncStatus: SyncStatus.synced,
      createdAt: now,
      updatedAt: now,
    );
  }

  setUp(() async {
    // 使用内存数据库进行测试
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LocalCustomerRepository(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  group('Property 3: 离线数据缓存完整性', () {
    /// Property Test: 保存后读取应该得到完全相同的数据
    test('should preserve customer data after save and load (round-trip)', () async {
      // 运行 100 次迭代
      for (var i = 0; i < 100; i++) {
        final original = generateRandomCustomer();

        // 保存到本地数据库
        final saved = await repository.createCustomer(original);

        // 从本地数据库读取
        final loaded = await repository.getCustomerById(saved.id);

        // 验证数据完整性
        expect(loaded, isNotNull);
        expect(loaded!.id, equals(saved.id));
        expect(loaded.name, equals(original.name));
        expect(loaded.phone, equals(original.phone));
        expect(loaded.email, equals(original.email));
        expect(loaded.owner, equals(original.owner));
        expect(loaded.status, equals(original.status));
      }
    });

    /// Property Test: 批量保存后应该能够完整读取所有数据
    test('should preserve all customers after batch save', () async {
      // 运行 20 次迭代，每次保存 5-10 个客户
      for (var iteration = 0; iteration < 20; iteration++) {
        // 清空数据库
        await database.clearAllData();

        final count = random.nextInt(6) + 5; // 5-10 个客户
        final customers = List.generate(count, (_) => generateRandomCustomer());

        // 批量保存
        for (final customer in customers) {
          await repository.createCustomer(customer);
        }

        // 读取所有客户
        final loaded = await repository.getAllCustomers();

        // 验证数量一致
        expect(loaded.length, equals(count));

        // 验证每个客户的数据完整性
        for (final original in customers) {
          final found = loaded.firstWhere(
            (c) => c.name == original.name && c.phone == original.phone,
            orElse: () => throw Exception('Customer not found: ${original.name}'),
          );
          expect(found.email, equals(original.email));
          expect(found.owner, equals(original.owner));
          expect(found.status, equals(original.status));
        }
      }
    });

    /// Property Test: 更新后应该保留更新的数据
    test('should preserve updated data after modification', () async {
      for (var i = 0; i < 50; i++) {
        final original = generateRandomCustomer();

        // 创建客户
        final created = await repository.createCustomer(original);

        // 生成新的随机数据进行更新
        final newName = '${randomString(4)}更新公司';
        final newPhone = randomPhone();
        final newEmail = randomEmail();

        final updated = created.copyWith(
          name: newName,
          phone: newPhone,
          email: newEmail,
        );

        // 更新客户
        await repository.updateCustomer(updated);

        // 读取更新后的数据
        final loaded = await repository.getCustomerById(created.id);

        // 验证更新后的数据
        expect(loaded, isNotNull);
        expect(loaded!.id, equals(created.id));
        expect(loaded.name, equals(newName));
        expect(loaded.phone, equals(newPhone));
        expect(loaded.email, equals(newEmail));
        // 原始数据应该被覆盖
        expect(loaded.name, isNot(equals(original.name)));
      }
    });

    /// Property Test: 删除后应该无法读取
    test('should not find customer after deletion', () async {
      for (var i = 0; i < 50; i++) {
        final customer = generateRandomCustomer();

        // 创建客户
        final created = await repository.createCustomer(customer);

        // 验证存在
        var loaded = await repository.getCustomerById(created.id);
        expect(loaded, isNotNull);

        // 删除客户
        await repository.deleteCustomer(created.id);

        // 验证不存在
        loaded = await repository.getCustomerById(created.id);
        expect(loaded, isNull);
      }
    });

    /// Property Test: 搜索应该返回匹配的结果
    test('should find customers by search keyword', () async {
      // 清空数据库
      await database.clearAllData();

      // 创建一些客户
      final customers = <CustomerEntity>[];
      for (var i = 0; i < 20; i++) {
        final customer = generateRandomCustomer();
        final created = await repository.createCustomer(customer);
        customers.add(created);
      }

      // 对每个客户进行搜索测试
      for (final customer in customers.take(10)) {
        // 使用客户名称的一部分进行搜索
        final keyword = customer.name.substring(0, min(3, customer.name.length));
        final results = await repository.searchCustomers(keyword);

        // 验证搜索结果包含该客户
        final found = results.any((c) => c.id == customer.id);
        expect(found, isTrue, reason: 'Customer ${customer.name} should be found with keyword "$keyword"');
      }
    });

    /// Property Test: 分页数据应该一致
    test('should return consistent paginated data', () async {
      // 清空数据库
      await database.clearAllData();

      // 创建 50 个客户
      final customers = <CustomerEntity>[];
      for (var i = 0; i < 50; i++) {
        final customer = generateRandomCustomer();
        final created = await repository.createCustomer(customer);
        customers.add(created);
      }

      // 测试分页
      const pageSize = 10;
      final allIds = <String>{};

      for (var page = 1; page <= 5; page++) {
        final pageData = await repository.getCustomersPaginated(
          page: page,
          pageSize: pageSize,
        );

        // 验证每页数量
        expect(pageData.length, equals(pageSize));

        // 验证没有重复
        for (final customer in pageData) {
          expect(allIds.contains(customer.id), isFalse,
              reason: 'Customer ${customer.id} should not appear in multiple pages');
          allIds.add(customer.id);
        }
      }

      // 验证总数
      expect(allIds.length, equals(50));
    });

    /// Property Test: 同步状态应该正确更新
    test('should correctly track sync status', () async {
      for (var i = 0; i < 30; i++) {
        final customer = generateRandomCustomer();

        // 创建客户（应该标记为 dirty）
        final created = await repository.createCustomer(customer);
        var loaded = await repository.getCustomerById(created.id);
        expect(loaded!.syncStatus, equals(SyncStatus.dirty));

        // 标记为已同步
        await repository.markAsSynced(created.id);
        loaded = await repository.getCustomerById(created.id);
        expect(loaded!.syncStatus, equals(SyncStatus.synced));

        // 更新客户（应该再次标记为 dirty）
        await repository.updateCustomer(loaded.copyWith(name: '${loaded.name}更新'));
        loaded = await repository.getCustomerById(created.id);
        expect(loaded!.syncStatus, equals(SyncStatus.dirty));
      }
    });
  });
}
