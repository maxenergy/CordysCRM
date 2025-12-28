import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/tables.dart';

part 'sync_queue_dao.g.dart';

/// 同步队列数据访问对象
@DriftAccessor(tables: [SyncQueue])
class SyncQueueDao extends DatabaseAccessor<AppDatabase>
    with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  /// 获取所有待同步项
  Future<List<SyncQueueItemData>> getPendingItems() {
    return (select(syncQueue)
          ..where((q) => q.status.equalsValue(SyncQueueItemStatus.pending))
          ..orderBy([(q) => OrderingTerm.asc(q.createdAt)]))
        .get();
  }

  /// 获取指定实体的待同步项
  Future<List<SyncQueueItemData>> getPendingItemsByEntity(
    String entityType,
    String entityId,
  ) {
    return (select(syncQueue)
          ..where((q) =>
              q.entityType.equals(entityType) &
              q.entityId.equals(entityId) &
              q.status.equalsValue(SyncQueueItemStatus.pending)))
        .get();
  }

  /// 获取失败的同步项（可重试）
  Future<List<SyncQueueItemData>> getFailedItems({int maxAttempts = 3}) {
    return (select(syncQueue)
          ..where((q) =>
              q.status.equalsValue(SyncQueueItemStatus.failed) &
              q.attemptCount.isSmallerThanValue(maxAttempts))
          ..orderBy([(q) => OrderingTerm.asc(q.createdAt)]))
        .get();
  }

  /// 获取过期的处理中同步项
  Future<List<SyncQueueItemData>> findInProgressBefore(DateTime cutoff) {
    return (select(syncQueue)
          ..where((q) =>
              q.status.equalsValue(SyncQueueItemStatus.inProgress) &
              q.updatedAt.isSmallerThanValue(cutoff))
          ..orderBy([(q) => OrderingTerm.asc(q.updatedAt)]))
        .get();
  }

  /// 添加同步项（防重复）
  ///
  /// 如果已存在相同实体和操作类型的待同步项，则更新 payload；否则插入新项
  Future<int> addSyncItem({
    required String entityType,
    required String entityId,
    required SyncOperation operation,
    required String payload,
  }) async {
    // 检查是否已存在相同实体的待同步项
    final existingItems = await getPendingItemsByEntity(entityType, entityId);
    
    // 如果存在相同操作类型的待同步项，更新 payload
    for (final item in existingItems) {
      if (item.operation == operation) {
        await (update(syncQueue)..where((q) => q.id.equals(item.id))).write(
          SyncQueueCompanion(
            payload: Value(payload),
            createdAt: Value(DateTime.now()),
          ),
        );
        return item.id;
      }
    }

    // 不存在则插入新项
    return into(syncQueue).insert(
      SyncQueueCompanion.insert(
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        payload: payload,
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  /// 更新同步项状态
  Future<int> updateItemStatus(int id, SyncQueueItemStatus status) {
    return (update(syncQueue)..where((q) => q.id.equals(id))).write(
      SyncQueueCompanion(
        status: Value(status),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 标记为处理中
  Future<int> markAsInProgress(int id) {
    return (update(syncQueue)..where((q) => q.id.equals(id))).write(
      SyncQueueCompanion(
        status: const Value(SyncQueueItemStatus.inProgress),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 标记为失败并增加重试次数
  Future<int> markAsFailed(int id) async {
    final item = await (select(syncQueue)..where((q) => q.id.equals(id)))
        .getSingleOrNull();
    if (item == null) return 0;

    return (update(syncQueue)..where((q) => q.id.equals(id))).write(
      SyncQueueCompanion(
        status: const Value(SyncQueueItemStatus.failed),
        attemptCount: Value(item.attemptCount + 1),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 更新重试次数
  Future<int> updateAttemptCount(int id, int count) {
    return (update(syncQueue)..where((q) => q.id.equals(id))).write(
      SyncQueueCompanion(
        attemptCount: Value(count),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 更新错误类型
  Future<int> updateErrorType(int id, String type) {
    return (update(syncQueue)..where((q) => q.id.equals(id))).write(
      SyncQueueCompanion(
        errorType: Value(type),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 更新错误消息
  Future<int> updateErrorMessage(int id, String message) {
    return (update(syncQueue)..where((q) => q.id.equals(id))).write(
      SyncQueueCompanion(
        errorMessage: Value(message),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 删除同步项（同步成功后）
  Future<int> deleteSyncItem(int id) {
    return (delete(syncQueue)..where((q) => q.id.equals(id))).go();
  }

  /// 删除指定实体的所有同步项
  Future<int> deleteSyncItemsByEntity(String entityType, String entityId) {
    return (delete(syncQueue)
          ..where((q) =>
              q.entityType.equals(entityType) & q.entityId.equals(entityId)))
        .go();
  }

  /// 清空失败且超过最大重试次数的同步项
  Future<int> clearFailedItems({int maxAttempts = 3}) {
    return (delete(syncQueue)
          ..where((q) =>
              q.status.equalsValue(SyncQueueItemStatus.failed) &
              q.attemptCount.isBiggerOrEqualValue(maxAttempts)))
        .go();
  }

  /// 获取待同步项数量
  Future<int> getPendingCount() async {
    final count = syncQueue.id.count();
    final query = selectOnly(syncQueue)
      ..addColumns([count])
      ..where(syncQueue.status.equalsValue(SyncQueueItemStatus.pending));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// 监听待同步项数量变化
  Stream<int> watchPendingCount() {
    final count = syncQueue.id.count();
    final query = selectOnly(syncQueue)
      ..addColumns([count])
      ..where(syncQueue.status.equalsValue(SyncQueueItemStatus.pending));
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  /// 检查是否存在相同实体的待同步项
  Future<bool> hasPendingItem(String entityType, String entityId) async {
    final items = await getPendingItemsByEntity(entityType, entityId);
    return items.isNotEmpty;
  }

  /// 获取致命错误项列表（超过最大重试次数）
  ///
  /// Requirements: 7.5
  Future<List<SyncQueueItemData>> getFatalItems({int maxAttempts = 5}) {
    return (select(syncQueue)
          ..where((q) =>
              q.status.equalsValue(SyncQueueItemStatus.failed) &
              q.attemptCount.isBiggerOrEqualValue(maxAttempts))
          ..orderBy([(q) => OrderingTerm.desc(q.updatedAt)]))
        .get();
  }

  /// 获取致命错误数量
  ///
  /// Requirements: 7.5
  Future<int> getFatalErrorCount({int maxAttempts = 5}) async {
    final count = syncQueue.id.count();
    final query = selectOnly(syncQueue)
      ..addColumns([count])
      ..where(syncQueue.status.equalsValue(SyncQueueItemStatus.failed) &
              syncQueue.attemptCount.isBiggerOrEqualValue(maxAttempts));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// 监听致命错误数量变化
  ///
  /// Requirements: 7.5
  Stream<int> watchFatalErrorCount({int maxAttempts = 5}) {
    final count = syncQueue.id.count();
    final query = selectOnly(syncQueue)
      ..addColumns([count])
      ..where(syncQueue.status.equalsValue(SyncQueueItemStatus.failed) &
              syncQueue.attemptCount.isBiggerOrEqualValue(maxAttempts));
    
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  /// 根据 ID 查找同步项
  ///
  /// Requirements: 7.2
  Future<SyncQueueItemData?> findById(int id) {
    return (select(syncQueue)..where((q) => q.id.equals(id)))
        .getSingleOrNull();
  }

  /// 重置致命错误项为待处理状态
  ///
  /// 将 fatal error 项重置为 pending 状态，并清空重试次数和错误信息
  /// Requirements: 7.5
  Future<int> resetFatalItem(int id) {
    return (update(syncQueue)..where((q) => q.id.equals(id))).write(
      SyncQueueCompanion(
        status: const Value(SyncQueueItemStatus.pending),
        attemptCount: const Value(0),
        errorType: const Value(null),
        errorMessage: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
