import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'dao/clue_dao.dart';
import 'dao/customer_dao.dart';
import 'dao/follow_record_dao.dart';
import 'dao/sync_queue_dao.dart';
import 'tables/tables.dart';

part 'app_database.g.dart';

/// CordysCRM 本地数据库
///
/// 使用 Drift ORM 管理本地 SQLite 数据库，支持离线数据存储和同步队列。
@DriftDatabase(
  tables: [Customers, Clues, FollowRecords, SyncQueue],
  daos: [CustomerDao, ClueDao, FollowRecordDao, SyncQueueDao],
)
class AppDatabase extends _$AppDatabase {
  /// 单例实例
  static AppDatabase? _instance;

  /// 获取数据库单例
  static AppDatabase get instance {
    _instance ??= AppDatabase._internal();
    return _instance!;
  }

  /// 私有构造函数
  AppDatabase._internal() : super(_openConnection());

  /// 用于测试的构造函数
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // 创建索引以优化查询性能
        await _createIndexes();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // 未来版本升级时在此处理迁移逻辑
      },
      beforeOpen: (details) async {
        // 启用外键约束
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// 创建数据库索引
  Future<void> _createIndexes() async {
    // customers 表索引
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_customers_sync_status ON customers(sync_status)');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_customers_updated_at ON customers(updated_at)');

    // clues 表索引
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_clues_sync_status ON clues(sync_status)');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_clues_updated_at ON clues(updated_at)');

    // follow_records 表索引
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_follow_records_customer_id ON follow_records(customer_id)');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_follow_records_clue_id ON follow_records(clue_id)');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_follow_records_sync_status ON follow_records(sync_status)');

    // sync_queue 表索引
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue(status)');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_sync_queue_entity ON sync_queue(entity_type, entity_id)');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_sync_queue_created_at ON sync_queue(created_at)');
  }

  /// 清空所有数据（用于登出或测试）
  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(syncQueue).go();
      await delete(followRecords).go();
      await delete(clues).go();
      await delete(customers).go();
    });
  }

  /// 关闭数据库连接
  Future<void> closeDatabase() async {
    await close();
    _instance = null;
  }
}

/// 打开数据库连接
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'cordyscrm.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
