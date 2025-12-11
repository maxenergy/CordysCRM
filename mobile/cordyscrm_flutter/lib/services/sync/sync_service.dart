import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/sources/local/app_database.dart';
import '../../data/sources/local/dao/sync_queue_dao.dart';
import 'sync_state.dart';

/// 同步服务
///
/// 负责管理离线数据同步，包括：
/// - 监听网络状态变化
/// - 网络恢复时自动触发同步
/// - 处理同步队列（推送本地修改到服务器）
/// - 拉取服务器增量数据
/// - 指数退避重试机制
class SyncService {
  SyncService({
    required AppDatabase db,
    Connectivity? connectivity,
    Duration debounce = const Duration(seconds: 3),
    Duration maxBackoff = const Duration(minutes: 5),
    int maxRetryAttempts = 5,
  })  : _db = db,
        _dao = db.syncQueueDao,
        _connectivity = connectivity ?? Connectivity(),
        _debounce = debounce,
        _maxBackoff = maxBackoff,
        _maxRetryAttempts = maxRetryAttempts {
    _init();
  }

  // ignore: unused_field - 预留给未来 API 调用使用
  final AppDatabase _db;
  final SyncQueueDao _dao;
  final Connectivity _connectivity;
  final Duration _debounce;
  final Duration _maxBackoff;
  final int _maxRetryAttempts;

  final _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  // 状态流控制器
  final _stateController = StreamController<SyncState>.broadcast();

  /// 同步状态流
  Stream<SyncState> get stateStream => _stateController.stream;

  // 内部状态
  SyncState _currentState = const SyncState();
  StreamSubscription<ConnectivityResult>? _connectivitySub;
  StreamSubscription<int>? _pendingCountSub;
  Timer? _debounceTimer;
  Timer? _retryTimer;
  int _retryAttempt = 0;
  bool _isSyncing = false;
  DateTime? _lastSyncedAt;

  // SharedPreferences key
  static const _lastSyncKey = 'last_sync_timestamp';

  /// 当前同步状态
  SyncState get currentState => _currentState;

  /// 初始化服务
  void _init() {
    // 发送初始状态
    _emit(const SyncState(status: SyncServiceStatus.idle));

    // 监听网络状态变化
    _connectivitySub = _connectivity.onConnectivityChanged.listen(_onConnectivityChangedSingle);

    // 监听待同步数量变化
    _pendingCountSub = _dao.watchPendingCount().listen((count) {
      _emit(_currentState.copyWith(pendingCount: count));
    });

    // 加载上次同步时间
    _loadLastSyncTime();

    // 检查初始网络状态
    _checkInitialConnectivity();
  }

  /// 加载上次同步时间
  Future<void> _loadLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_lastSyncKey);
      if (timestamp != null) {
        _lastSyncedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
        _emit(_currentState.copyWith(lastSyncedAt: _lastSyncedAt));
      }
    } catch (e) {
      _logger.w('加载上次同步时间失败: $e');
    }
  }

  /// 保存同步时间
  Future<void> _saveLastSyncTime(DateTime time) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSyncKey, time.millisecondsSinceEpoch);
      _lastSyncedAt = time;
    } catch (e) {
      _logger.w('保存同步时间失败: $e');
    }
  }

  /// 检查初始网络状态
  Future<void> _checkInitialConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _onConnectivityChangedSingle(result);
    } catch (e) {
      _logger.w('检查网络状态失败: $e');
    }
  }

  /// 网络状态变化处理（单个结果）
  void _onConnectivityChangedSingle(ConnectivityResult result) {
    final isOnline = result != ConnectivityResult.none;

    if (!isOnline) {
      _logger.i('网络已断开');
      _emit(_currentState.copyWith(status: SyncServiceStatus.offline));
      _cancelPendingOperations();
      return;
    }

    // 网络恢复，触发去抖同步
    _logger.i('网络已恢复，准备同步...');
    triggerSync(reason: '网络恢复');
  }

  /// 取消待处理的操作
  void _cancelPendingOperations() {
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
  }

  /// 触发同步（带去抖）
  ///
  /// [reason] 触发原因，用于日志记录
  /// [immediate] 是否立即执行，跳过去抖
  Future<void> triggerSync({String? reason, bool immediate = false}) async {
    _debounceTimer?.cancel();

    if (immediate) {
      await _runSync(reason: reason);
    } else {
      _debounceTimer = Timer(_debounce, () => _runSync(reason: reason));
    }
  }

  /// 执行同步
  Future<void> _runSync({String? reason}) async {
    // 防止重复同步
    if (_isSyncing) {
      _logger.d('同步正在进行中，跳过本次请求');
      return;
    }

    // 检查网络状态
    final connectivity = await _connectivity.checkConnectivity();
    final isOnline = connectivity != ConnectivityResult.none;
    if (!isOnline) {
      _logger.d('当前离线，跳过同步');
      _emit(_currentState.copyWith(status: SyncServiceStatus.offline));
      return;
    }

    _isSyncing = true;
    _logger.i('开始同步${reason != null ? " (原因: $reason)" : ""}');
    _emit(_currentState.copyWith(
      status: SyncServiceStatus.syncing,
      clearError: true,
      progress: 0.0,
    ));

    try {
      // 1. 推送本地修改到服务器
      await _pushLocalChanges();

      // 2. 拉取服务器增量数据
      await _pullServerChanges();

      // 同步成功
      _retryAttempt = 0;
      final syncTime = DateTime.now();
      await _saveLastSyncTime(syncTime);

      final pendingCount = await _dao.getPendingCount();
      _emit(_currentState.copyWith(
        status: SyncServiceStatus.succeeded,
        pendingCount: pendingCount,
        lastSyncedAt: syncTime,
        progress: 1.0,
      ));

      _logger.i('同步完成');

      // 短暂显示成功状态后恢复为 idle
      Future.delayed(const Duration(seconds: 2), () {
        if (_currentState.status == SyncServiceStatus.succeeded) {
          _emit(_currentState.copyWith(status: SyncServiceStatus.idle));
        }
      });
    } catch (e, stackTrace) {
      _logger.e('同步失败: $e', error: e, stackTrace: stackTrace);
      _handleSyncError(e);
    } finally {
      _isSyncing = false;
    }
  }

  /// 处理同步错误
  void _handleSyncError(Object error) {
    _retryAttempt++;

    final errorMessage = _getErrorMessage(error);
    _emit(_currentState.copyWith(
      status: SyncServiceStatus.failed,
      error: errorMessage,
    ));

    // 判断是否可重试
    if (_isRetryableError(error) && _retryAttempt < _maxRetryAttempts) {
      final backoff = _calculateBackoff();
      _logger.i('将在 ${backoff.inSeconds} 秒后重试 (第 $_retryAttempt 次)');

      _retryTimer = Timer(backoff, () {
        triggerSync(reason: '自动重试', immediate: true);
      });
    } else if (_retryAttempt >= _maxRetryAttempts) {
      _logger.w('已达到最大重试次数 ($_maxRetryAttempts)，停止重试');
    }
  }

  /// 计算指数退避时间
  Duration _calculateBackoff() {
    final baseMs = pow(2, _retryAttempt).toInt() * 500;
    final cappedMs = min(baseMs, _maxBackoff.inMilliseconds);
    // 添加随机抖动 (±20%)
    final jitter = (cappedMs * 0.2 * (Random().nextDouble() * 2 - 1)).toInt();
    return Duration(milliseconds: cappedMs + jitter);
  }

  /// 判断错误是否可重试
  bool _isRetryableError(Object error) {
    final errorStr = error.toString().toLowerCase();
    // 网络错误、超时、服务器错误 (5xx) 可重试
    // 客户端错误 (4xx) 不可重试
    return errorStr.contains('timeout') ||
        errorStr.contains('network') ||
        errorStr.contains('connection') ||
        errorStr.contains('socket') ||
        errorStr.contains('500') ||
        errorStr.contains('502') ||
        errorStr.contains('503') ||
        errorStr.contains('504');
  }

  /// 获取用户友好的错误信息
  String _getErrorMessage(Object error) {
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('timeout')) {
      return '连接超时，请检查网络';
    } else if (errorStr.contains('network') || errorStr.contains('connection')) {
      return '网络连接失败';
    } else if (errorStr.contains('401') || errorStr.contains('unauthorized')) {
      return '认证失败，请重新登录';
    } else if (errorStr.contains('403') || errorStr.contains('forbidden')) {
      return '没有权限执行此操作';
    } else if (errorStr.contains('404')) {
      return '请求的资源不存在';
    } else if (errorStr.contains('500') || errorStr.contains('server')) {
      return '服务器错误，请稍后重试';
    }
    return '同步失败: ${error.toString()}';
  }

  /// 推送本地修改到服务器
  Future<void> _pushLocalChanges() async {
    _logger.d('开始推送本地修改...');

    // 获取待同步项（包括 pending 和可重试的 failed 项）
    final pendingItems = await _dao.getPendingItems();
    final failedItems = await _dao.getFailedItems(maxAttempts: _maxRetryAttempts);
    final allItems = [...pendingItems, ...failedItems];
    
    if (allItems.isEmpty) {
      _logger.d('没有待同步的本地修改');
      return;
    }

    _logger.i('发现 ${allItems.length} 个待同步项 (pending: ${pendingItems.length}, failed: ${failedItems.length})');

    int processed = 0;
    int failed = 0;
    for (final item in allItems) {
      try {
        // 标记为处理中
        await _dao.markAsInProgress(item.id);

        // 根据操作类型调用对应 API
        await _processSyncItem(item);

        // 同步成功，删除队列项
        await _dao.deleteSyncItem(item.id);

        processed++;
        _emit(_currentState.copyWith(
          progress: processed / allItems.length * 0.5, // 推送占 50% 进度
        ));
      } catch (e) {
        _logger.e('同步项 ${item.id} 失败: $e');
        failed++;

        // 标记为失败（会增加 attemptCount）
        await _dao.markAsFailed(item.id);

        // 如果是不可恢复错误，继续处理下一项
        // 如果是可恢复错误且还有重试机会，也继续处理下一项
        // 只有当所有项都是可恢复错误时才中断
        if (!_isRetryableError(e)) {
          _logger.w('同步项 ${item.id} 遇到不可恢复错误，跳过');
          continue;
        }
        
        // 可恢复错误，继续处理其他项，最后统一重试
        _logger.d('同步项 ${item.id} 遇到可恢复错误，稍后重试');
      }
    }

    _logger.d('本地修改推送完成: 成功 $processed, 失败 $failed');
    
    // 如果有失败项且是可恢复错误，抛出异常触发重试
    if (failed > 0) {
      throw Exception('部分同步项失败 ($failed/${allItems.length})');
    }
  }

  /// 处理单个同步项
  Future<void> _processSyncItem(SyncQueueItemData item) async {
    _logger.d('处理同步项: ${item.entityType}/${item.entityId} (${item.operation})');

    // TODO: 实现实际的 API 调用
    // 这里需要根据 entityType 和 operation 调用对应的后端 API
    // 示例：
    // switch (item.entityType) {
    //   case 'customers':
    //     await _syncCustomer(item);
    //     break;
    //   case 'clues':
    //     await _syncClue(item);
    //     break;
    //   case 'follow_records':
    //     await _syncFollowRecord(item);
    //     break;
    // }

    // 模拟 API 调用延迟
    await Future.delayed(const Duration(milliseconds: 100));
  }

  /// 拉取服务器增量数据
  Future<void> _pullServerChanges() async {
    _logger.d('开始拉取服务器数据...');

    // TODO: 实现实际的增量拉取逻辑
    // 1. 调用 API 获取 lastSyncedAt 之后的变更数据
    // 2. 使用 upsert 逻辑更新本地数据库
    // 示例：
    // final delta = await _api.getChanges(since: _lastSyncedAt);
    // await _db.transaction(() async {
    //   for (final change in delta.customers) {
    //     await _db.customerDao.upsert(change);
    //   }
    //   for (final change in delta.clues) {
    //     await _db.clueDao.upsert(change);
    //   }
    // });

    _emit(_currentState.copyWith(progress: 1.0));
    _logger.d('服务器数据拉取完成');
  }

  /// 发送状态更新
  void _emit(SyncState state) {
    _currentState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    _cancelPendingOperations();
    await _connectivitySub?.cancel();
    await _pendingCountSub?.cancel();
    await _stateController.close();
  }
}
