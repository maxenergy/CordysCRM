import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/tables.dart';

part 'follow_record_dao.g.dart';

/// 跟进记录数据访问对象
@DriftAccessor(tables: [FollowRecords])
class FollowRecordDao extends DatabaseAccessor<AppDatabase>
    with _$FollowRecordDaoMixin {
  FollowRecordDao(super.db);

  /// 获取所有跟进记录
  Future<List<FollowRecordData>> getAllFollowRecords() =>
      select(followRecords).get();

  /// 根据ID获取跟进记录
  Future<FollowRecordData?> getFollowRecordById(String id) {
    return (select(followRecords)..where((r) => r.id.equals(id)))
        .getSingleOrNull();
  }

  /// 获取客户的跟进记录
  Future<List<FollowRecordData>> getFollowRecordsByCustomerId(
      String customerId) {
    return (select(followRecords)
          ..where((r) => r.customerId.equals(customerId))
          ..orderBy([(r) => OrderingTerm.desc(r.followAt)]))
        .get();
  }

  /// 获取线索的跟进记录
  Future<List<FollowRecordData>> getFollowRecordsByClueId(String clueId) {
    return (select(followRecords)
          ..where((r) => r.clueId.equals(clueId))
          ..orderBy([(r) => OrderingTerm.desc(r.followAt)]))
        .get();
  }

  /// 根据同步状态查询跟进记录
  Future<List<FollowRecordData>> getFollowRecordsBySyncStatus(
      SyncStatus status) {
    return (select(followRecords)
          ..where((r) => r.syncStatus.equalsValue(status)))
        .get();
  }

  /// 获取待同步的跟进记录
  Future<List<FollowRecordData>> getDirtyFollowRecords() {
    return getFollowRecordsBySyncStatus(SyncStatus.dirty);
  }

  /// 监听客户的跟进记录变化
  Stream<List<FollowRecordData>> watchFollowRecordsByCustomerId(
      String customerId) {
    return (select(followRecords)
          ..where((r) => r.customerId.equals(customerId))
          ..orderBy([(r) => OrderingTerm.desc(r.followAt)]))
        .watch();
  }

  /// 插入或更新跟进记录
  ///
  /// 注意：跟进记录必须关联到客户或线索（至少一个不为空）
  Future<void> upsertFollowRecord(FollowRecordData record) {
    // 业务层验证：确保至少关联一个客户或线索
    if (record.customerId == null && record.clueId == null) {
      throw ArgumentError('跟进记录必须关联到客户或线索（customerId 或 clueId 至少一个不为空）');
    }
    return into(followRecords).insertOnConflictUpdate(record);
  }

  /// 批量插入或更新跟进记录
  ///
  /// 注意：每条跟进记录必须关联到客户或线索（至少一个不为空）
  Future<void> upsertFollowRecords(List<FollowRecordData> records) async {
    // 业务层验证：确保每条记录至少关联一个客户或线索
    for (final record in records) {
      if (record.customerId == null && record.clueId == null) {
        throw ArgumentError('跟进记录必须关联到客户或线索（customerId 或 clueId 至少一个不为空）');
      }
    }
    await batch((batch) {
      batch.insertAllOnConflictUpdate(followRecords, records);
    });
  }

  /// 删除跟进记录
  Future<int> deleteFollowRecord(String id) {
    return (delete(followRecords)..where((r) => r.id.equals(id))).go();
  }

  /// 更新跟进记录同步状态
  Future<int> updateSyncStatus(String id, SyncStatus status) {
    return (update(followRecords)..where((r) => r.id.equals(id))).write(
      FollowRecordsCompanion(
        syncStatus: Value(status),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 标记跟进记录为已同步
  Future<int> markAsSynced(String id) {
    return updateSyncStatus(id, SyncStatus.synced);
  }

  /// 标记跟进记录为待同步
  Future<int> markAsDirty(String id) {
    return updateSyncStatus(id, SyncStatus.dirty);
  }
}
