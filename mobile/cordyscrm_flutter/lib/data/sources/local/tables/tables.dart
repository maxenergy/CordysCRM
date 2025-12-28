import 'package:drift/drift.dart';

// ==================== 枚举定义 ====================

/// 同步状态
enum SyncStatus {
  /// 已同步
  synced,

  /// 待同步（本地有修改）
  dirty,
}

/// 同步队列中的操作类型
enum SyncOperation {
  create,
  update,
  delete,
}

/// 同步队列项状态
enum SyncQueueItemStatus {
  pending,
  inProgress,
  failed,
}

// ==================== 表定义 ====================

/// 客户表
@DataClassName('CustomerData')
class Customers extends Table {
  @override
  String get tableName => 'customers';

  /// 客户ID（UUID）
  TextColumn get id => text()();

  /// 客户名称
  TextColumn get name => text()();

  /// 联系电话
  TextColumn get phone => text().nullable()();

  /// 邮箱
  TextColumn get email => text().nullable()();

  /// 负责人
  TextColumn get owner => text().nullable()();

  /// 客户状态
  TextColumn get status => text().withDefault(const Constant('active'))();

  /// 同步状态
  IntColumn get syncStatus =>
      intEnum<SyncStatus>().withDefault(Constant(SyncStatus.synced.index))();

  /// 创建时间
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// 更新时间
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 线索表
@DataClassName('ClueData')
class Clues extends Table {
  @override
  String get tableName => 'clues';

  /// 线索ID（UUID）
  TextColumn get id => text()();

  /// 线索名称
  TextColumn get name => text()();

  /// 联系电话
  TextColumn get phone => text().nullable()();

  /// 来源
  TextColumn get source => text().nullable()();

  /// 线索状态
  TextColumn get status => text().withDefault(const Constant('new'))();

  /// 同步状态
  IntColumn get syncStatus =>
      intEnum<SyncStatus>().withDefault(Constant(SyncStatus.synced.index))();

  /// 创建时间
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// 更新时间
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 跟进记录表
@DataClassName('FollowRecordData')
class FollowRecords extends Table {
  @override
  String get tableName => 'follow_records';

  /// 记录ID（UUID）
  TextColumn get id => text()();

  /// 关联客户ID（外键）
  TextColumn get customerId =>
      text().nullable().references(Customers, #id, onDelete: KeyAction.cascade)();

  /// 关联线索ID（外键）
  TextColumn get clueId =>
      text().nullable().references(Clues, #id, onDelete: KeyAction.cascade)();

  /// 跟进内容
  TextColumn get content => text()();

  /// 跟进类型（phone/visit/wechat/email）
  TextColumn get followType => text().nullable()();

  /// 跟进时间
  DateTimeColumn get followAt => dateTime().withDefault(currentDateAndTime)();

  /// 同步状态
  IntColumn get syncStatus =>
      intEnum<SyncStatus>().withDefault(Constant(SyncStatus.synced.index))();

  /// 创建时间
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// 更新时间
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 同步队列表
@DataClassName('SyncQueueItemData')
class SyncQueue extends Table {
  @override
  String get tableName => 'sync_queue';

  /// 自增主键
  IntColumn get id => integer().autoIncrement()();

  /// 实体类型（customers/clues/follow_records）
  TextColumn get entityType => text()();

  /// 实体ID
  TextColumn get entityId => text()();

  /// 操作类型
  IntColumn get operation => intEnum<SyncOperation>()();

  /// 操作数据（JSON字符串）
  TextColumn get payload => text()();

  /// 队列项状态
  IntColumn get status => intEnum<SyncQueueItemStatus>()
      .withDefault(Constant(SyncQueueItemStatus.pending.index))();

  /// 重试次数
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();

  /// 错误类型（retryable/nonRetryable/fatal）
  TextColumn get errorType => text().nullable()();

  /// 错误消息
  TextColumn get errorMessage => text().nullable()();

  /// 创建时间
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// 更新时间
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
