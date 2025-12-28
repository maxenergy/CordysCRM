// Task 16.3: 重试次数限制测试
// Feature: core-data-integrity
// Requirements: 7.1, 7.2, 7.3, 7.4
// Property: 7

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:cordyscrm_flutter/data/sources/local/app_database.dart';
import 'package:cordyscrm_flutter/data/sources/local/tables/tables.dart';
import 'package:cordyscrm_flutter/services/sync/api_client_monitor.dart';
import 'package:cordyscrm_flutter/services/sync/sync_api_client.dart';
import 'package:cordyscrm_flutter/services/sync/sync_service.dart';

@GenerateMocks([SyncApiClient])
import 'sync_retry_limit_test.mocks.dart';

void main() {
  late AppDatabase db;
  late ApiClientMonitor clientMonitor;
  late MockSyncApiClient mockApiClient;
  late SyncService syncService;

  setUp(() async {
    db = AppDatabase.memory();
    clientMonitor = ApiClientMonitor();
    mockApiClient = MockSyncApiClient();
    
    clientMonitor.setClient(mockApiClient);
    
    syncService = SyncService(
      db: db,
      clientMonitor: clientMonitor,
      maxRetryAttempts: 5,
    );
  });

  tearDown(() async {
    await syncService.dispose();
    await db.close();
  });

  group('Task 16.3: 重试次数限制', () {
    test('达到 5 次重试后应该标记为 Fatal', () async {
      // Arrange: 创建已失败 4 次的队列项
      final itemId = await db.syncQueueDao.addToQueue(
        entityType: 'customers',
        entityId: 'test-customer-fatal',
        operation: SyncOperation.create,
        payload: {'id': 'test-customer-fatal', 'name': 'Test'},
      );
      
      // 设置 attemptCount = 4
      await db.syncQueueDao.updateAttemptCount(itemId, 4);
      await db.syncQueueDao.updateItemStatus(itemId, SyncQueueItemStatus.failed);
      await db.syncQueueDao.updateErrorType(itemId, 'retryable');

      // Mock API 继续抛出可重试错误（5xx）
      when(mockApiClient.pushChanges(any)).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/api/sync/push'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/api/sync/push'),
            statusCode: 500,
            data: {'error': 'Internal Server Error'},
          ),
        ),
      );

      // Act: 触发同步（第 5 次失败）
      await syncService.triggerSync(reason: 'Test', immediate: true);
      await Future.delayed(const Duration(milliseconds: 200));

      // Assert: 验证达到最大重试次数
      final item = await db.syncQueueDao.findById(itemId);
      expect(item, isNotNull);
      expect(item!.attemptCount, equals(5));
      expect(item.errorType, equals('fatal'));
      expect(item.errorMessage, contains('超过最大重试次数'));
    });

    test('Fatal 错误应该触发用户通知', () async {
      // Arrange: 创建已失败 4 次的队列项
      final itemId = await db.syncQueueDao.addToQueue(
        entityType: 'customers',
        entityId: 'test-customer-notify',
        operation: SyncOperation.create,
        payload: {'id': 'test-customer-notify', 'name': 'Test Customer'},
      );
      
      await db.syncQueueDao.updateAttemptCount(itemId, 4);
      await db.syncQueueDao.updateItemStatus(itemId, SyncQueueItemStatus.failed);

      // Mock API 抛出错误
      when(mockApiClient.pushChanges(any)).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/api/sync/push'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      // 监听通知流
      final notifications = <String>[];
      final subscription = syncService.notificationStream.listen((notification) {
        notifications.add(notification);
      });

      // Act: 触发同步
      await syncService.triggerSync(reason: 'Test', immediate: true);
      await Future.delayed(const Duration(milliseconds: 300));

      // Assert: 验证收到通知
      expect(notifications, isNotEmpty);
      expect(
        notifications.first,
        contains('同步失败'),
      );
      expect(
        notifications.first,
        contains('customers'),
      );

      await subscription.cancel();
    });

    test('Property 7: 每次重试后 attemptCount 应该递增 1', () async {
      // Arrange: 创建多个不同 attemptCount 的队列项
      final testCases = [0, 1, 2, 3, 4];
      
      for (final initialCount in testCases) {
        final itemId = await db.syncQueueDao.addToQueue(
          entityType: 'customers',
          entityId: 'test-customer-$initialCount',
          operation: SyncOperation.create,
          payload: {'id': 'test-customer-$initialCount', 'name': 'Test'},
        );
        
        await db.syncQueueDao.updateAttemptCount(itemId, initialCount);
        if (initialCount > 0) {
          await db.syncQueueDao.updateItemStatus(itemId, SyncQueueItemStatus.failed);
        }
      }

      // Mock API 抛出可重试错误
      when(mockApiClient.pushChanges(any)).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/api/sync/push'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      // Act: 触发同步
      await syncService.triggerSync(reason: 'Test', immediate: true);
      await Future.delayed(const Duration(milliseconds: 300));

      // Assert: 验证每个项的 attemptCount 都递增了 1
      for (final initialCount in testCases) {
        final item = await db.syncQueueDao.findByEntityId('test-customer-$initialCount');
        expect(item, isNotNull);
        
        if (initialCount < 5) {
          expect(
            item!.attemptCount,
            equals(initialCount + 1),
            reason: 'Item with initial count $initialCount should increment to ${initialCount + 1}',
          );
        }
      }
    });

    test('Fatal 错误项不应该被自动重试', () async {
      // Arrange: 创建已标记为 Fatal 的队列项
      final itemId = await db.syncQueueDao.addToQueue(
        entityType: 'customers',
        entityId: 'test-customer-no-retry',
        operation: SyncOperation.create,
        payload: {'id': 'test-customer-no-retry', 'name': 'Test'},
      );
      
      await db.syncQueueDao.updateAttemptCount(itemId, 5);
      await db.syncQueueDao.updateItemStatus(itemId, SyncQueueItemStatus.failed);
      await db.syncQueueDao.updateErrorType(itemId, 'fatal');

      // Mock API（不应该被调用）
      when(mockApiClient.pushChanges(any)).thenAnswer((_) async => [
            SyncPushResult(localId: 'test-customer-no-retry', isSuccess: true),
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

      // Act: 触发同步
      await syncService.triggerSync(reason: 'Test', immediate: true);
      await Future.delayed(const Duration(milliseconds: 200));

      // Assert: 验证 API 没有被调用（Fatal 项被跳过）
      verifyNever(mockApiClient.pushChanges(any));

      // 验证队列项仍然存在且状态未变
      final item = await db.syncQueueDao.findById(itemId);
      expect(item, isNotNull);
      expect(item!.attemptCount, equals(5));
      expect(item.errorType, equals('fatal'));
    });

    test('持续失败 5 次应该停止重试', () async {
      // Arrange: 创建新的队列项
      final itemId = await db.syncQueueDao.addToQueue(
        entityType: 'customers',
        entityId: 'test-customer-persistent-fail',
        operation: SyncOperation.create,
        payload: {'id': 'test-customer-persistent-fail', 'name': 'Test'},
      );

      // Mock API 持续抛出可重试错误
      when(mockApiClient.pushChanges(any)).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/api/sync/push'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      // Act: 模拟 5 次失败
      for (int i = 0; i < 5; i++) {
        await syncService.triggerSync(reason: 'Test attempt ${i + 1}', immediate: true);
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Assert: 验证最终状态
      final item = await db.syncQueueDao.findById(itemId);
      expect(item, isNotNull);
      expect(item!.attemptCount, equals(5));
      expect(item.errorType, equals('fatal'));
      
      // 验证不再被重试（API 调用次数应该是 5 次）
      verify(mockApiClient.pushChanges(any)).called(5);
    });

    test('fatalErrorCount 应该正确统计', () async {
      // Arrange: 创建多个队列项，部分标记为 Fatal
      final items = [
        {'id': 'item-1', 'attempts': 5, 'errorType': 'fatal'},
        {'id': 'item-2', 'attempts': 3, 'errorType': 'retryable'},
        {'id': 'item-3', 'attempts': 5, 'errorType': 'fatal'},
        {'id': 'item-4', 'attempts': 2, 'errorType': 'retryable'},
      ];

      for (final item in items) {
        final itemId = await db.syncQueueDao.addToQueue(
          entityType: 'customers',
          entityId: item['id'] as String,
          operation: SyncOperation.create,
          payload: {'id': item['id'], 'name': 'Test'},
        );
        
        await db.syncQueueDao.updateAttemptCount(itemId, item['attempts'] as int);
        await db.syncQueueDao.updateItemStatus(itemId, SyncQueueItemStatus.failed);
        await db.syncQueueDao.updateErrorType(itemId, item['errorType'] as String);
      }

      // Act: 获取 Fatal 错误数量
      final fatalCount = await db.syncQueueDao.getFatalErrorCount(maxAttempts: 5);

      // Assert: 应该有 2 个 Fatal 错误
      expect(fatalCount, equals(2));
    });
  });
}
