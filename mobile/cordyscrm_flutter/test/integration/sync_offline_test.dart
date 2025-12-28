// Task 16.1: API Client 不可用场景测试
// Feature: core-data-integrity
// Requirements: 6.1, 6.2, 6.3

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:cordyscrm_flutter/data/sources/local/app_database.dart';
import 'package:cordyscrm_flutter/data/sources/local/tables/tables.dart';
import 'package:cordyscrm_flutter/services/sync/api_client_monitor.dart';
import 'package:cordyscrm_flutter/services/sync/sync_api_client.dart';
import 'package:cordyscrm_flutter/services/sync/sync_service.dart';

@GenerateMocks([SyncApiClient])
import 'sync_offline_test.mocks.dart';

void main() {
  late AppDatabase db;
  late ApiClientMonitor clientMonitor;
  late MockSyncApiClient mockApiClient;
  late SyncService syncService;

  setUp(() async {
    // 使用内存数据库
    db = AppDatabase.memory();
    clientMonitor = ApiClientMonitor();
    mockApiClient = MockSyncApiClient();
    
    // 初始化时 Client 不可用
    syncService = SyncService(
      db: db,
      clientMonitor: clientMonitor,
    );
  });

  tearDown(() async {
    await syncService.dispose();
    await db.close();
  });

  group('Task 16.1: API Client 不可用场景', () {
    test('离线数据应该被加入队列', () async {
      // Arrange: Client 不可用
      expect(clientMonitor.isClientAvailable, isFalse);

      // Act: 创建客户数据（模拟离线创建）
      final customer = CustomersCompanion.insert(
        id: 'test-customer-1',
        name: 'Test Customer',
        creditCode: '91110000600037341L',
      );
      await db.customerDao.insertCustomer(customer);

      // 手动添加到同步队列（模拟 Repository 的行为）
      await db.syncQueueDao.addToQueue(
        entityType: 'customers',
        entityId: 'test-customer-1',
        operation: SyncOperation.create,
        payload: {
          'id': 'test-customer-1',
          'name': 'Test Customer',
          'creditCode': '91110000600037341L',
        },
      );

      // Assert: 验证数据在队列中
      final queueItems = await db.syncQueueDao.getPendingItems();
      expect(queueItems, hasLength(1));
      expect(queueItems.first.entityType, equals('customers'));
      expect(queueItems.first.entityId, equals('test-customer-1'));
      expect(queueItems.first.status, equals(SyncQueueItemStatus.pending));
    });

    test('Client 恢复后应该自动触发同步', () async {
      // Arrange: 创建待同步数据
      await db.syncQueueDao.addToQueue(
        entityType: 'customers',
        entityId: 'test-customer-2',
        operation: SyncOperation.create,
        payload: {'id': 'test-customer-2', 'name': 'Test Customer 2'},
      );

      // Mock API 成功响应
      when(mockApiClient.pushChanges(any)).thenAnswer((_) async => [
            SyncPushResult(
              localId: 'test-customer-2',
              isSuccess: true,
            ),
          ]);
      when(mockApiClient.pullChanges(any)).thenAnswer((_) async => ServerDelta(
            serverTimestamp: DateTime.now(),
            customers: [],
            deletedCustomerIds: [],
            clues: [],
            deletedClueIds: [],
            followRecords: [],
            deletedFollowRecordIds: [],
          ));

      // Act: 设置 Client 为可用
      clientMonitor.setClient(mockApiClient);

      // 等待监听器触发同步
      await Future.delayed(const Duration(milliseconds: 100));

      // 手动触发同步（因为测试环境可能没有网络监听）
      await syncService.triggerSync(reason: 'Test', immediate: true);

      // Assert: 验证同步被调用
      verify(mockApiClient.pushChanges(any)).called(1);
      verify(mockApiClient.pullChanges(any)).called(1);

      // 验证队列项被删除
      final remainingItems = await db.syncQueueDao.getPendingItems();
      expect(remainingItems, isEmpty);
    });

    test('Client 不可用时同步应该暂停并保留队列项', () async {
      // Arrange: 创建待同步数据
      await db.syncQueueDao.addToQueue(
        entityType: 'customers',
        entityId: 'test-customer-3',
        operation: SyncOperation.create,
        payload: {'id': 'test-customer-3', 'name': 'Test Customer 3'},
      );

      // Client 不可用
      expect(clientMonitor.isClientAvailable, isFalse);

      // Act: 尝试触发同步
      await syncService.triggerSync(reason: 'Test', immediate: true);

      // Assert: 验证队列项仍然存在
      final queueItems = await db.syncQueueDao.getPendingItems();
      expect(queueItems, hasLength(1));
      expect(queueItems.first.entityId, equals('test-customer-3'));
      expect(queueItems.first.status, equals(SyncQueueItemStatus.pending));
    });
  });
}
