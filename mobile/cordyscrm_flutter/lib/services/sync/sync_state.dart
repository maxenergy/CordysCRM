// 同步状态定义
//
// 定义离线同步功能的状态枚举和状态类

// ==================== 同步状态枚举 ====================

/// 同步服务状态（区别于数据库的 SyncStatus）
enum SyncServiceStatus {
  /// 空闲状态
  idle,

  /// 正在同步
  syncing,

  /// 同步成功
  succeeded,

  /// 同步失败
  failed,

  /// 离线状态
  offline,
}

// ==================== 同步状态类 ====================

/// 同步状态
///
/// 包含同步的当前状态、待同步数量、错误信息和最后同步时间
class SyncState {
  const SyncState({
    this.status = SyncServiceStatus.idle,
    this.pendingCount = 0,
    this.fatalErrorCount = 0,
    this.error,
    this.lastSyncedAt,
    this.progress,
  });

  /// 当前同步状态
  final SyncServiceStatus status;

  /// 待同步项数量
  final int pendingCount;

  /// 致命错误数量（超过最大重试次数的项）
  final int fatalErrorCount;

  /// 错误信息（仅在 failed 状态时有值）
  final String? error;

  /// 最后成功同步时间
  final DateTime? lastSyncedAt;

  /// 同步进度（0.0 - 1.0）
  final double? progress;

  /// 是否正在同步
  bool get isSyncing => status == SyncServiceStatus.syncing;

  /// 是否离线
  bool get isOffline => status == SyncServiceStatus.offline;

  /// 是否有待同步项
  bool get hasPendingItems => pendingCount > 0;

  /// 复制并修改
  ///
  /// 注意：error 和 progress 使用特殊处理：
  /// - 传入 null 保持原值
  /// - 传入空字符串 '' 清除 error
  /// - 传入 -1.0 清除 progress
  SyncState copyWith({
    SyncServiceStatus? status,
    int? pendingCount,
    int? fatalErrorCount,
    String? error,
    DateTime? lastSyncedAt,
    double? progress,
    bool clearError = false,
    bool clearProgress = false,
  }) {
    return SyncState(
      status: status ?? this.status,
      pendingCount: pendingCount ?? this.pendingCount,
      fatalErrorCount: fatalErrorCount ?? this.fatalErrorCount,
      error: clearError ? null : (error ?? this.error),
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      progress: clearProgress ? null : (progress ?? this.progress),
    );
  }

  @override
  String toString() {
    return 'SyncState(status: $status, pendingCount: $pendingCount, '
        'fatalErrorCount: $fatalErrorCount, error: $error, '
        'lastSyncedAt: $lastSyncedAt, progress: $progress)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncState &&
        other.status == status &&
        other.pendingCount == pendingCount &&
        other.fatalErrorCount == fatalErrorCount &&
        other.error == error &&
        other.lastSyncedAt == lastSyncedAt &&
        other.progress == progress;
  }

  @override
  int get hashCode {
    return Object.hash(
      status,
      pendingCount,
      fatalErrorCount,
      error,
      lastSyncedAt,
      progress,
    );
  }
}
