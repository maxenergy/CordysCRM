import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sources/local/app_database.dart';
import 'api_client_monitor.dart';
import 'sync_service.dart';
import 'sync_state.dart';

// ==================== Database Provider ====================

/// 数据库 Provider
///
/// 提供 AppDatabase 单例实例
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instance;
});

// ==================== API Client Monitor Provider ====================

/// API Client 监控器 Provider
///
/// 提供 ApiClientMonitor 单例实例，用于监控 API Client 可用性
final apiClientMonitorProvider = Provider<ApiClientMonitor>((ref) {
  return ApiClientMonitor();
});

// ==================== Sync Service Provider ====================

/// 同步服务 Provider
///
/// 提供 SyncService 单例实例，自动管理生命周期
final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final clientMonitor = ref.watch(apiClientMonitorProvider);
  final service = SyncService(
    db: db,
    clientMonitor: clientMonitor,
  );

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

// ==================== Sync State Notifier ====================

/// 同步状态 Notifier
///
/// 管理同步状态，提供触发同步的方法
class SyncNotifier extends StateNotifier<SyncState> {
  SyncNotifier({required SyncService service})
      : _service = service,
        super(const SyncState()) {
    _bind();
  }

  final SyncService _service;
  StreamSubscription<SyncState>? _subscription;

  /// 绑定服务状态流
  void _bind() {
    // 设置初始状态
    state = _service.currentState;

    // 监听状态变化
    _subscription = _service.stateStream.listen((newState) {
      state = newState;
    });
  }

  /// 手动触发同步
  Future<void> triggerSync() async {
    await _service.triggerSync(reason: '手动触发', immediate: true);
  }

  /// 静默触发同步（带去抖）
  Future<void> triggerSyncSilent() async {
    await _service.triggerSync(reason: '静默触发');
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// 同步状态 Provider
///
/// 提供同步状态和触发同步的方法
final syncNotifierProvider =
    StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  final service = ref.watch(syncServiceProvider);
  return SyncNotifier(service: service);
});

// ==================== Convenience Providers ====================

/// 同步状态 Provider
final syncStatusProvider = Provider<SyncServiceStatus>((ref) {
  return ref.watch(syncNotifierProvider).status;
});

/// 待同步数量 Provider
final pendingSyncCountProvider = Provider<int>((ref) {
  return ref.watch(syncNotifierProvider).pendingCount;
});

/// 是否正在同步 Provider
final isSyncingProvider = Provider<bool>((ref) {
  return ref.watch(syncNotifierProvider).isSyncing;
});

/// 是否离线 Provider
final isOfflineProvider = Provider<bool>((ref) {
  return ref.watch(syncNotifierProvider).isOffline;
});

/// 最后同步时间 Provider
final lastSyncedAtProvider = Provider<DateTime?>((ref) {
  return ref.watch(syncNotifierProvider).lastSyncedAt;
});

/// 同步错误信息 Provider
final syncErrorProvider = Provider<String?>((ref) {
  return ref.watch(syncNotifierProvider).error;
});
