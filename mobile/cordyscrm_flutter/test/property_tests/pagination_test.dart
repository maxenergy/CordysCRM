import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
// ignore: unused_import
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';

import 'package:cordyscrm_flutter/data/sources/local/app_database.dart';
import 'package:cordyscrm_flutter/data/sources/local/tables/tables.dart';
import 'package:cordyscrm_flutter/data/repositories/local_customer_repository.dart';

/// **Feature: crm-mobile-enterprise-ai, Property 1: 分页数据一致性**
/// **Validates: Requirements 1.3**
///
/// For any 客户列表分页请求，返回的数据量应该等于请求的 pageSize（最后一页除外），
/// 且总数应该与实际数据库记录数一致。
void main() {
  late AppDatabase database;
  late LocalCustomerRepository repository;
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
  });

  tearDown(() async {
    await database.close();
  });

  group('Property 1: 分页数据一致性', () {
    /// Property Test: 分页返回的数据量应该等于 pageSize（最后一页除外）
    test('should return correct page size for non-last pages', () async {
      // 运行 20 次迭代，每次使用不同的数据量和页大小
      for (var iteration = 0; iteration < 20; iteration++) {
        await database.clearAllData();

        // 随机生成 30-100 条数据
        final totalCount = random.nextInt(71) + 30;
        for (var i = 0; i < totalCount; i++) {
          await repository.createCustomer(generateRandomCustomer());
        }

        // 随机选择页大小 (5-20)
        final pageSize = random.nextInt(16) + 5;
        final totalPages = (totalCount / pageSize).ceil();

        // 验证每一页的数据量
        for (var page = 1; page <= totalPages; page++) {
          final pageData = await repository.getCustomersPaginated(
            page: page,
            pageSize: pageSize,
          );

          if (page < totalPages) {
            // 非最后一页应该返回完整的 pageSize
            expect(pageData.length, equals(pageSize),
                reason: 'Page $page should have $pageSize items (total: $totalCount, pageSize: $pageSize)');
          } else {
            // 最后一页应该返回剩余的数据
            final expectedLastPageSize = totalCount - (totalPages - 1) * pageSize;
            expect(pageData.length, equals(expectedLastPageSize),
                reason: 'Last page should have $expectedLastPageSize items');
          }
        }
      }
    });

    /// Property Test: 所有分页数据的总和应该等于总记录数
    test('should return all records across all pages', () async {
      for (var iteration = 0; iteration < 20; iteration++) {
        await database.clearAllData();

        // 随机生成 20-80 条数据
        final totalCount = random.nextInt(61) + 20;
        for (var i = 0; i < totalCount; i++) {
          await repository.createCustomer(generateRandomCustomer());
        }

        // 随机选择页大小 (5-15)
        final pageSize = random.nextInt(11) + 5;
        final totalPages = (totalCount / pageSize).ceil();

        // 收集所有分页数据
        final allIds = <String>{};
        for (var page = 1; page <= totalPages; page++) {
          final pageData = await repository.getCustomersPaginated(
            page: page,
            pageSize: pageSize,
          );
          for (final customer in pageData) {
            allIds.add(customer.id);
          }
        }

        // 验证总数一致
        expect(allIds.length, equals(totalCount),
            reason: 'Total records across all pages should equal $totalCount');
      }
    });

    /// Property Test: 分页数据不应该有重复
    test('should not have duplicate records across pages', () async {
      for (var iteration = 0; iteration < 20; iteration++) {
        await database.clearAllData();

        // 随机生成 30-60 条数据
        final totalCount = random.nextInt(31) + 30;
        for (var i = 0; i < totalCount; i++) {
          await repository.createCustomer(generateRandomCustomer());
        }

        // 随机选择页大小 (5-10)
        final pageSize = random.nextInt(6) + 5;
        final totalPages = (totalCount / pageSize).ceil();

        // 收集所有分页数据的 ID
        final allIds = <String>[];
        for (var page = 1; page <= totalPages; page++) {
          final pageData = await repository.getCustomersPaginated(
            page: page,
            pageSize: pageSize,
          );
          allIds.addAll(pageData.map((c) => c.id));
        }

        // 验证没有重复
        final uniqueIds = allIds.toSet();
        expect(uniqueIds.length, equals(allIds.length),
            reason: 'There should be no duplicate records across pages');
      }
    });

    /// Property Test: 空页面请求应该返回空列表
    test('should return empty list for pages beyond data', () async {
      for (var iteration = 0; iteration < 10; iteration++) {
        await database.clearAllData();

        // 随机生成 10-30 条数据
        final totalCount = random.nextInt(21) + 10;
        for (var i = 0; i < totalCount; i++) {
          await repository.createCustomer(generateRandomCustomer());
        }

        // 随机选择页大小 (5-10)
        final pageSize = random.nextInt(6) + 5;
        final totalPages = (totalCount / pageSize).ceil();

        // 请求超出范围的页面
        final beyondPage = totalPages + random.nextInt(5) + 1;
        final pageData = await repository.getCustomersPaginated(
          page: beyondPage,
          pageSize: pageSize,
        );

        expect(pageData, isEmpty,
            reason: 'Page $beyondPage should be empty (total pages: $totalPages)');
      }
    });

    /// Property Test: 总数查询应该与实际数据一致
    test('should return correct total count', () async {
      for (var iteration = 0; iteration < 20; iteration++) {
        await database.clearAllData();

        // 随机生成 0-50 条数据
        final totalCount = random.nextInt(51);
        for (var i = 0; i < totalCount; i++) {
          await repository.createCustomer(generateRandomCustomer());
        }

        // 验证总数
        final count = await repository.getCustomerCount();
        expect(count, equals(totalCount),
            reason: 'Customer count should be $totalCount');
      }
    });
  });
}
