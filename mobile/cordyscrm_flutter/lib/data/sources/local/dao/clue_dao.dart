import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/tables.dart';

part 'clue_dao.g.dart';

/// 线索数据访问对象
@DriftAccessor(tables: [Clues])
class ClueDao extends DatabaseAccessor<AppDatabase> with _$ClueDaoMixin {
  ClueDao(super.db);

  /// 获取所有线索
  Future<List<ClueData>> getAllClues() => select(clues).get();

  /// 根据ID获取线索
  Future<ClueData?> getClueById(String id) {
    return (select(clues)..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  /// 根据同步状态查询线索
  Future<List<ClueData>> getCluesBySyncStatus(SyncStatus status) {
    return (select(clues)..where((c) => c.syncStatus.equalsValue(status)))
        .get();
  }

  /// 获取待同步的线索
  Future<List<ClueData>> getDirtyClues() {
    return getCluesBySyncStatus(SyncStatus.dirty);
  }

  /// 监听所有线索变化
  Stream<List<ClueData>> watchAllClues() => select(clues).watch();

  /// 插入或更新线索
  Future<void> upsertClue(ClueData clue) {
    return into(clues).insertOnConflictUpdate(clue);
  }

  /// 批量插入或更新线索
  Future<void> upsertClues(List<ClueData> clueList) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(clues, clueList);
    });
  }

  /// 删除线索
  Future<int> deleteClue(String id) {
    return (delete(clues)..where((c) => c.id.equals(id))).go();
  }

  /// 更新线索同步状态
  Future<int> updateSyncStatus(String id, SyncStatus status) {
    return (update(clues)..where((c) => c.id.equals(id))).write(
      CluesCompanion(
        syncStatus: Value(status),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 标记线索为已同步
  Future<int> markAsSynced(String id) {
    return updateSyncStatus(id, SyncStatus.synced);
  }

  /// 标记线索为待同步
  Future<int> markAsDirty(String id) {
    return updateSyncStatus(id, SyncStatus.dirty);
  }
}
