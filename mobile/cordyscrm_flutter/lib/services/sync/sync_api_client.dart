import '../../data/sources/local/app_database.dart';
import '../../data/sources/local/tables/tables.dart' show SyncStatus;

/// 服务器增量数据响应
///
/// 包含自上次同步以来的所有变更数据
class ServerDelta {
  const ServerDelta({
    required this.serverTimestamp,
    this.customers = const [],
    this.deletedCustomerIds = const [],
    this.clues = const [],
    this.deletedClueIds = const [],
    this.followRecords = const [],
    this.deletedFollowRecordIds = const [],
  });

  /// 服务器时间戳，用于下次增量同步
  final DateTime serverTimestamp;

  /// 更新的客户数据
  final List<CustomerData> customers;

  /// 已删除的客户 ID
  final List<String> deletedCustomerIds;

  /// 更新的线索数据
  final List<ClueData> clues;

  /// 已删除的线索 ID
  final List<String> deletedClueIds;

  /// 更新的跟进记录
  final List<FollowRecordData> followRecords;

  /// 已删除的跟进记录 ID
  final List<String> deletedFollowRecordIds;

  /// 是否为空（无任何变更）
  bool get isEmpty =>
      customers.isEmpty &&
      deletedCustomerIds.isEmpty &&
      clues.isEmpty &&
      deletedClueIds.isEmpty &&
      followRecords.isEmpty &&
      deletedFollowRecordIds.isEmpty;

  /// 从 JSON 解析
  factory ServerDelta.fromJson(Map<String, dynamic> json) {
    return ServerDelta(
      serverTimestamp: DateTime.parse(json['timestamp'] as String),
      customers: (json['customers']?['updated'] as List<dynamic>?)
              ?.map((e) => parseCustomer(e as Map<String, dynamic>))
              .toList() ??
          [],
      deletedCustomerIds:
          (json['customers']?['deleted'] as List<dynamic>?)?.cast<String>() ??
              [],
      clues: (json['clues']?['updated'] as List<dynamic>?)
              ?.map((e) => parseClue(e as Map<String, dynamic>))
              .toList() ??
          [],
      deletedClueIds:
          (json['clues']?['deleted'] as List<dynamic>?)?.cast<String>() ?? [],
      followRecords: (json['followRecords']?['updated'] as List<dynamic>?)
              ?.map((e) => parseFollowRecord(e as Map<String, dynamic>))
              .toList() ??
          [],
      deletedFollowRecordIds:
          (json['followRecords']?['deleted'] as List<dynamic>?)
                  ?.cast<String>() ??
              [],
    );
  }

  /// 解析客户数据
  static CustomerData parseCustomer(Map<String, dynamic> json) {
    return CustomerData(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      owner: json['owner'] as String?,
      status: json['status'] as String? ?? 'active',
      syncStatus: SyncStatus.synced,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// 解析线索数据
  static ClueData parseClue(Map<String, dynamic> json) {
    return ClueData(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      source: json['source'] as String?,
      status: json['status'] as String? ?? 'new',
      syncStatus: SyncStatus.synced,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// 解析跟进记录数据
  static FollowRecordData parseFollowRecord(Map<String, dynamic> json) {
    return FollowRecordData(
      id: json['id'] as String,
      customerId: json['customerId'] as String?,
      clueId: json['clueId'] as String?,
      content: json['content'] as String,
      followType: json['followType'] as String?,
      followAt: DateTime.parse(json['followAt'] as String),
      syncStatus: SyncStatus.synced,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

/// 推送结果
class PushResult {
  const PushResult({
    required this.localId,
    required this.status,
    this.serverId,
    this.serverUpdatedAt,
    this.serverVersion,
    this.errorMessage,
  });

  /// 本地 ID
  final String localId;

  /// 状态: success, conflict, error
  final String status;

  /// 服务器分配的 ID（仅 create 操作）
  final String? serverId;

  /// 服务器更新时间
  final DateTime? serverUpdatedAt;

  /// 冲突时的服务器版本数据
  final Map<String, dynamic>? serverVersion;

  /// 错误信息
  final String? errorMessage;

  bool get isSuccess => status == 'success';
  bool get isConflict => status == 'conflict';
  bool get isError => status == 'error';

  factory PushResult.fromJson(Map<String, dynamic> json) {
    return PushResult(
      localId: json['localId'] as String,
      status: json['status'] as String,
      serverId: json['serverId'] as String?,
      serverUpdatedAt: json['serverUpdatedAt'] != null
          ? DateTime.parse(json['serverUpdatedAt'] as String)
          : null,
      serverVersion: json['serverVersion'] as Map<String, dynamic>?,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}

/// 同步 API 客户端接口
///
/// 定义与后端同步的 API 接口，实际实现需要注入到 SyncService
abstract class SyncApiClient {
  /// 拉取自 lastSyncedAt 以来的增量变更
  ///
  /// [lastSyncedAt] 为 null 时视为首次全量同步
  Future<ServerDelta> pullChanges(DateTime? lastSyncedAt);

  /// 推送本地待同步的数据
  ///
  /// 返回每个操作的结果，包括成功、冲突或错误
  Future<List<PushResult>> pushChanges(List<SyncPushItem> items);
}

/// 推送项
class SyncPushItem {
  const SyncPushItem({
    required this.localId,
    required this.entityType,
    required this.operation,
    required this.payload,
    this.baseUpdatedAt,
  });

  /// 本地 ID
  final String localId;

  /// 实体类型: customers, clues, follow_records
  final String entityType;

  /// 操作类型: create, update, delete
  final String operation;

  /// 数据负载 (JSON)
  final Map<String, dynamic> payload;

  /// 基准更新时间（用于冲突检测）
  final DateTime? baseUpdatedAt;

  Map<String, dynamic> toJson() {
    return {
      'localId': localId,
      'entityType': entityType,
      'operation': operation,
      'payload': payload,
      if (baseUpdatedAt != null)
        'baseUpdatedAt': baseUpdatedAt!.toIso8601String(),
    };
  }
}
