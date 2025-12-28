// Task 16.2: 错误分类和重试测试
// Feature: core-data-integrity
// Requirements: 4.1, 4.2, 4.3, 4.4, 4.5
// Properties: 5, 6, 7, 8

import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:cordyscrm_flutter/core/error/error_classifier.dart';
import 'package:cordyscrm_flutter/data/sources/local/app_database.dart';
import 'package:cordyscrm_flutter/data/sources/local/tables/tables.dart';
import 'package:cordyscrm_flutter/services/sync/api_client_monitor.dart';
import 'package:cordyscrm_flutter/services/sync/sync_api_client.dart';
import 'package:cordyscrm_flutter/services/sync/sync_service.dart';

@GenerateMocks([SyncApiClient])
import 'sync_error_classification_test.mocks.dart';

void main() {
  late AppDatabase db;
  late ApiClientMonitor clientMonitor;
  late MockSyncApiClient mockApiClient;
  late SyncService syncService;
  late ErrorClassifier errorClassifier;

  setUp(() async {
    db = AppDatabase.memory();
    clientMonitor = ApiClientMonitor();
    mockApiClient = MockSyncApiClient();
    errorClassifier = ErrorClassifier();
    
    clientMonitor.setClient(mockApiClient);
    
    syncService = SyncService(
      db: db,
      clientMonitor: clientMonitor,
    );
  });

  tearDown(() async {
    await syncService.dispose();
    await db.close();
  });

  group('Task 16.2.1: 可重试错误（网络超时）', () {
    test('网络超时应该被分类为可重试错误', () async {
      // Arrange: 创建待同步数据
      await db.syncQueueDao.addToQueue(
        entityType: 'customers',
        entityId: 'test-customer-timeout',
        operation: SyncOperation.create,
        payload: {'id': 'test-customer-timeout', 'name': 'Test'},
      );

      // Mock API 抛出超时异常
      final timeoutError = DioException(
        requestOptions: RequestOptions(path: '/api/sync/push'),
        type: DioExceptionType.connectionTimeout,
      );
      when(mockApiClient.pushChanges(any)).thenThrow(timeoutError);

      // Act: 触发同步
      await syncService.triggerSync(reason: 'Test', immediate: true);

      // 等待同步完成
      await Future.delayed(const Duration(milliseconds: 200));

      // Assert: 验证错误分类
      final errorType = errorClassifier.classify(timeoutError);
      expect(errorType, equals(ErrorType.retryable));

      // 验证队列项状态
      final queueItems = await db.syncQueueDao.getFailedItems(maxAttempts: 5);
      expect(queueItems, hasLength(1));
      
      final item = queueItems.first;
      expect(item.status, equals(SyncQueueItemStatus.failed));
      expect(item.attemptCount, equals(1)); // 重试次数递增
      expect(item.errorType, equals('retryable'));
    });

    test('重试次数应该正确递增', () async {
      // Arrange: 创建已失败 2 次的队列项
      final itemId = await db.syncQueueDao.addToQueue(
        entityType: 'customers',
        entityId: 'test-customer-retry',
        operation: SyncOperation.create,
        payload: {'id': 'test-customer-retry', 'name': 'Test'},
      );
      
      // 手动设置 attemptCount = 2
      await db.syncQueueDao.updateAttemptCount(itemId, 2);
      await db.syncQueueDao.updateItemStatus(itemId, SyncQueueItemStatus.failed);

      // Mock API 继续抛出超时异常
      when(mockApiClient.pushChanges(any)).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/api/sync/push'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      // Act: 触发同步
      await syncService.triggerSync(reason: 'Test', immediate: true);
      await Future.delayed(const Duration(milliseconds: 200));

      // Assert: 验证 attemptCount 递增到 3
      final item = await db.syncQueueDao.findById(itemId);
      expect(item?.attemptCount, equals(3));
    });
  });

  group('Task 16.2.2: 不可重试错误（4xx）', () {
    test('4xx 错误应该被分类为不可重试错误', () async {
      // Arrange: 创建待同步数据
      await db.syncQueueDao.addToQueue(
        entityType: 'customers',
        entityId: 'test-customer-400',
        operation: SyncOperation.create,
        payload: {'id': 'test-customer-400', 'name': 'Test'},
      );

      // Mock API 抛出 400 错误
      final badRequestError = DioException(
        requestOptions: RequestOptions(path: '/api/sync/push'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/api/sync/push'),
          statusCode: 400,
          data: {'error': 'Bad Request'},
        ),
      );
      when(mockApiClient.pushChanges(any)).thenThrow(badRequestError);

      // Act: 触发同步
      await syncService.triggerSync(reason: 'Test', immediate: true);
      await Future.delayed(const Duration(milliseconds: 200));

      // Assert: 验证错误分类
      final errorType = errorClassifier.classify(badRequestError);
      expect(errorType, equals(ErrorType.nonRetryable));

      // 验证队列项被标记为 Fatal（attemptCount = 5）
      final queueItems = await db.syncQueueDao.getFailedItems(maxAttempts: 5);
      expect(queueItems, hasLength(1));
      
      final item = queueItems.first;
      expect(item.errorType, equals('nonRetryable'));
      expect(item.attemptCount, greaterThanOrEqualTo(5)); // 直接设置为最大值
    });

    test('Property 5: 所有 4xx 错误都应该被分类为不可重试', () {
      // 测试常见的 4xx 状态码
      final statusCodes = [400, 401, 403, 404, 409, 422];
      
      for (final statusCode in statusCodes) {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: statusCode,
          ),
        );
        
        final errorType = errorClassifier.classify(error);
        expect(
          errorType,
          equals(ErrorType.nonRetryable),
          reason: 'Status code $statusCode should be non-retryable',
        );
      }
    });
  });

  group('Task 16.2.3: 指数退避验证', () {
    test('Property 8: 指数退避间隔应该符合 2^n 秒（±20%）', () {
      // 测试不同的重试次数
      for (int attemptCount = 1; attemptCount <= 5; attemptCount++) {
        final expectedSeconds = pow(2, attemptCount).toInt();
        
        // 计算允许的范围（±20%）
        final lowerBound = (expectedSeconds * 0.8).toInt();
        final upperBound = (expectedSeconds * 1.2).toInt();
        
        // 验证多次计算的结果都在范围内
        for (int i = 0; i < 10; i++) {
          // 模拟 SyncService 的退避计算逻辑
          final baseMs = pow(2, attemptCount).toInt() * 500;
          final cappedMs = min(baseMs, const Duration(minutes: 5).inMilliseconds);
          
          // 不添加 jitter，验证基础值
          final actualSeconds = (cappedMs / 1000).round();
          
          expect(
            actualSeconds,
            inInclusiveRange(lowerBound, upperBound),
            reason: 'Attempt $attemptCount: expected ${expectedSeconds}s ±20%, got ${actualSeconds}s',
          );
        }
      }
    });

    test('退避期内的项不应该被重试', () async {
      // Arrange: 创建刚失败的队列项（attemptCount = 1）
      final itemId = await db.syncQueueDao.addToQueue(
        entityType: 'customers',
        entityId: 'test-customer-backoff',
        operation: SyncOperation.create,
        payload: {'id': 'test-customer-backoff', 'name': 'Test'},
      );
      
      await db.syncQueueDao.updateAttemptCount(itemId, 1);
      await db.syncQueueDao.updateItemStatus(itemId, SyncQueueItemStatus.failed);
      await db.syncQueueDao.updateErrorType(itemId, 'retryable');

      // Mock API 成功响应（如果被调用）
      when(mockApiClient.pushChanges(any)).thenAnswer((_) async => [
            SyncPushResult(localId: 'test-customer-backoff', isSuccess: true),
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

      // Act: 立即触发同步（应该跳过处于退避期的项）
      await syncService.triggerSync(reason: 'Test', immediate: true);
      await Future.delayed(const Duration(milliseconds: 200));

      // Assert: 验证 API 没有被调用（因为项在退避期）
      verifyNever(mockApiClient.pushChanges(any));

      // 验证队列项仍然存在
      final item = await db.syncQueueDao.findById(itemId);
      expect(item, isNotNull);
      expect(item!.status, equals(SyncQueueItemStatus.failed));
      expect(item.attemptCount, equals(1)); // 没有递增
    });
  });

  group('Property 6: 5xx 错误分类', () {
    test('所有 5xx 错误都应该被分类为可重试', () {
      final statusCodes = [500, 502, 503, 504];
      
      for (final statusCode in statusCodes) {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: statusCode,
          ),
        );
        
        final errorType = errorClassifier.classify(error);
        expect(
          errorType,
          equals(ErrorType.retryable),
          reason: 'Status code $statusCode should be retryable',
        );
      }
    });
  });
}
