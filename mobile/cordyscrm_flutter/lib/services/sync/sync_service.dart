import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/error/error_classifier.dart';
import '../../data/sources/local/app_database.dart';
import '../../data/sources/local/dao/sync_queue_dao.dart';
import '../../data/sources/local/tables/tables.dart'
    show SyncOperation, SyncQueueItemStatus;
import 'api_client_monitor.dart';
import 'sync_api_client.dart';
import 'sync_state.dart';
import 'sync_state_recovery.dart';
import 'sync_statistics.dart';

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
    required ApiClientMonitor clientMonitor,
    Connectivity? connectivity,
    Duration debounce = const Duration(seconds: 3),
    Duration maxBackoff = const Duration(minutes: 5),
    int maxRetryAttempts = 5,
  })  : _db = db,
        _dao = db.syncQueueDao,
        _clientMonitor = clientMonitor,
        _connectivity = connectivity ?? Connectivity(),
        _debounce = debounce,
        _maxBackoff = maxBackoff,
        _maxRetryAttempts = maxRetryAttempts {
    _init();
  }

  final AppDatabase _db;
  final SyncQueueDao _dao;
  final ApiClientMonitor _clientMonitor;
  final Connectivity _connectivity;
  final Duration _debounce;
  final Duration _maxBackoff;
  final int _maxRetryAttempts;

  final _logger = Logger(printer: PrettyPrinter(methodCount: 0));
  final _errorClassifier = ErrorClassifier();
  final _statistics = SyncStatistics();

  // 状态流控制器
  final _stateController = StreamController<SyncState>.broadcast();

  /// 同步状态流
  Stream<SyncState> get stateStream => _stateController.stream;

  // 通知流控制器（用于一次性事件通知，如 Toast/SnackBar）
  final _notificationController = StreamController<String>.broadcast();

  /// 通知流
  ///
  /// 用于发送一次性事件通知，如致命错误提示
  /// Requirements: 7.4
  Stream<String> get notificationStream => _notificationController.stream;

  // 内部状态
  SyncState _currentState = const SyncState();
  StreamSubscription<ConnectivityResult>? _connectivitySub;
  StreamSubscription<int>? _pendingCountSub;
  StreamSubscription<int>? _fatalCountSub;
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

    // 监听致命错误数量变化 (Requirement 7.5)
    _fatalCountSub = _dao.watchFatalErrorCount(maxAttempts: _maxRetryAttempts)
        .listen((count) {
      _emit(_currentState.copyWith(fatalErrorCount: count));
    });

    // 监听 API Client 状态变化 (Requirement 6.3: 自动恢复)
    _clientMonitor.addListener(_onClientAvailabilityChanged);

    // 加载上次同步时间
    _loadLastSyncTime();

    // 检查初始网络状态
    _checkInitialConnectivity();

    // 启动状态恢复机制
    _recoverState();
  }

  /// API Client 可用性变化处理
  ///
  /// Requirements: 6.2, 6.3
  void _onClientAvailabilityChanged() {
    if (_clientMonitor.isClientAvailable) {
      _logger.i('API Client 已恢复，触发同步');
      triggerSync(reason: 'API Client 恢复');
    } else {
      _logger.w('API Client 已移除，暂停同步');
      // 取消待处理的同步操作
      _cancelPendingOperations();
    }
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

  /// 恢复同步状态
  ///
  /// 在服务初始化时调用，用于：
  /// 1. 重置长时间处于 InProgress 状态的队列项（防止应用崩溃导致的状态卡死）
  /// 2. 验证同步队列完整性
  ///
  /// 错误处理：记录日志但不抛出异常，避免阻塞服务启动
  Future<void> _recoverState() async {
    final recovery = SyncStateRecovery(_db, _logger);
    try {
      final resetCount = await recovery.resetStaleInProgressItems();
      if (resetCount > 0) {
        _logger.i('状态恢复: 重置了 $resetCount 个过期的同步项');
      }

      final isValid = await recovery.validateQueueIntegrity();
      if (!isValid) {
        _logger.w('状态恢复: 队列完整性验证发现问题，请检查日志');
      }
    } catch (e, stackTrace) {
      _logger.e('状态恢复失败', error: e, stackTrace: stackTrace);
      // 不抛出异常，避免阻塞服务启动
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
    _statistics.reset(); // 重置统计数据
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
      // 注意：lastSyncedAt 已在 _pullServerChanges 中使用服务器时间戳更新

      final pendingCount = await _dao.getPendingCount();
      _emit(_currentState.copyWith(
        status: SyncServiceStatus.succeeded,
        pendingCount: pendingCount,
        lastSyncedAt: _lastSyncedAt,
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
    // 特殊处理：Client 不可用不需要重试（由 Monitor 监听器负责恢复）
    if (error is ClientUnavailableException) {
      _logger.w('API Client 不可用，等待恢复');
      _emit(_currentState.copyWith(
        status: SyncServiceStatus.offline,
        error: error.message,
      ));
      return;
    }

    _retryAttempt++;

    final errorMessage = _getErrorMessage(error);
    _emit(_currentState.copyWith(
      status: SyncServiceStatus.failed,
      error: errorMessage,
    ));

    // 使用 ErrorClassifier 判断是否可重试
    final errorType = _errorClassifier.classify(error);
    final canRetry = errorType == ErrorType.retryable && 
                     _retryAttempt < _maxRetryAttempts;

    if (canRetry) {
      final backoff = _calculateBackoff();
      _logger.i('将在 ${backoff.inSeconds} 秒后重试 (第 $_retryAttempt 次)');

      _retryTimer = Timer(backoff, () {
        triggerSync(reason: '自动重试', immediate: true);
      });
    } else if (_retryAttempt >= _maxRetryAttempts) {
      _logger.w('已达到最大重试次数 ($_maxRetryAttempts)，停止重试');
    } else {
      _logger.w('遇到不可重试错误 (${errorType.name})，停止重试');
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

  /// 计算单个项的退避时间是否满足
  ///
  /// 实现指数退避策略：第 n 次重试需要等待 2^n 秒
  /// Requirements: 4.5, Property 8
  bool _shouldRetryItem(SyncQueueItemData item) {
    if (item.attemptCount == 0) return true;

    // 2^n 秒 (例: 2^1=2s, 2^2=4s, 2^3=8s, 2^4=16s, 2^5=32s)
    final waitSeconds = pow(2, item.attemptCount);
    final nextRetryTime = item.updatedAt.add(Duration(seconds: waitSeconds.toInt()));
    
    final shouldRetry = DateTime.now().isAfter(nextRetryTime);
    if (!shouldRetry) {
      final remainingSeconds = nextRetryTime.difference(DateTime.now()).inSeconds;
      _logger.d('同步项 ${item.id} 处于退避期，还需等待 $remainingSeconds 秒');
    }
    
    return shouldRetry;
  }

  /// 推送本地修改到服务器
  ///
  /// Requirements: 4.4, 4.5, 7.2, 7.3, 7.4
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
    DateTime? minNextRetryTime; // 追踪最早的重试时间
    
    for (final item in allItems) {
      // 检查单项退避策略 (Per-Item Backoff)
      // Requirements: 4.5, Property 8
      if (item.status == SyncQueueItemStatus.failed) {
        if (!_shouldRetryItem(item)) {
          // 计算该项的下一次重试时间
          final waitSeconds = pow(2, item.attemptCount);
          final nextRetry = item.updatedAt.add(Duration(seconds: waitSeconds.toInt()));
          
          // 更新最早唤醒时间
          if (minNextRetryTime == null || nextRetry.isBefore(minNextRetryTime)) {
            minNextRetryTime = nextRetry;
          }
          continue; // 跳过处于退避期的项
        }
      }

      try {
        // 标记为处理中
        await _dao.markAsInProgress(item.id);

        // 根据操作类型调用对应 API
        await _processSyncItem(item);

        // 同步成功，删除队列项
        await _dao.deleteSyncItem(item.id);

        processed++;
        _statistics.recordSuccess();
        _emit(_currentState.copyWith(
          progress: processed / allItems.length * 0.5, // 推送占 50% 进度
        ));
      } on ClientUnavailableException catch (e) {
        // API Client 不可用，保留队列项并中断同步
        _logger.w('API Client 不可用，保留队列项 ${item.id} 并暂停同步: $e');
        // 将状态重置为 Pending，等待 Client 恢复
        await _dao.updateItemStatus(item.id, SyncQueueItemStatus.pending);
        // 中断循环，不继续处理后续项
        throw ClientUnavailableException('API Client 不可用，已暂停同步');
      } catch (e) {
        _logger.e('同步项 ${item.id} 失败: $e');

        // 使用 ErrorClassifier 分类错误
        final errorType = _errorClassifier.classify(e);
        _statistics.recordFailure(errorType);

        // 标记为失败（会增加 attemptCount）
        // Requirements: 7.2, Property 7
        await _dao.markAsFailed(item.id);
        
        // 计算新的重试次数 (markAsFailed 已经 +1)
        final newAttemptCount = item.attemptCount + 1;

        // 检查是否超过最大重试次数
        // Requirements: 7.3, 7.4
        if (newAttemptCount >= _maxRetryAttempts) {
          _logger.e('同步项 ${item.id} 达到最大重试次数 ($newAttemptCount)，标记为致命错误');
          await _dao.updateErrorType(item.id, 'fatal');
          await _dao.updateErrorMessage(
            item.id,
            '超过最大重试次数 ($_maxRetryAttempts): ${e.toString()}',
          );
          
          // 发送用户通知 (Requirement 7.4)
          _notificationController.add(
            '同步失败：${item.entityType} 数据已停止重试（ID: ${item.entityId}）',
          );
          
          continue; // 跳过此项后续处理
        }

        // 根据错误类型决定处理策略
        if (errorType == ErrorType.nonRetryable) {
          _logger.w('同步项 ${item.id} 遇到不可重试错误 (${errorType.name})');
          await _dao.updateErrorType(item.id, 'nonRetryable');
          await _dao.updateErrorMessage(item.id, e.toString());
          
          // 不可重试错误直接标记为 Fatal，避免无效重试
          await _dao.updateAttemptCount(item.id, _maxRetryAttempts);
          
          _notificationController.add(
            '同步失败：数据格式错误，已停止重试（${item.entityType} ID: ${item.entityId}）',
          );
          
          continue;
        }
        
        // 可重试错误，记录并继续处理其他项
        await _dao.updateErrorType(item.id, 'retryable');
        await _dao.updateErrorMessage(item.id, e.toString());
        _logger.d('同步项 ${item.id} 遇到可重试错误 (${errorType.name})，将在 ${pow(2, newAttemptCount)} 秒后重试');
      }
    }

    _logger.i('本地修改推送完成: $_statistics');
    
    // 如果有因退避而被跳过的项，安排唤醒定时器
    // 防止"静默失败"：所有项都在退避期时，服务会误判为成功
    if (minNextRetryTime != null) {
      final now = DateTime.now();
      if (minNextRetryTime.isAfter(now)) {
        final delay = minNextRetryTime.difference(now);
        _logger.d('存在处于退避期的项，将在 ${delay.inSeconds} 秒后唤醒服务');
        
        // 取消旧的 timer，设置新的唤醒 timer
        _retryTimer?.cancel();
        _retryTimer = Timer(delay, () {
          triggerSync(reason: '退避期结束唤醒', immediate: true);
        });
      } else {
        // 理论上不会走到这里，除非计算期间时间流逝，保险起见立即触发
        _logger.d('退避期已结束，立即触发同步');
        triggerSync(reason: '退避期结束唤醒', immediate: true);
      }
    }
    
    // 根据统计决定是否触发全局重试
    if (_statistics.shouldTriggerGlobalRetry()) {
      throw Exception(
        '存在 ${_statistics.retryableFailedCount} 个可重试的失败项，触发全局重试'
      );
    } else if (_statistics.nonRetryableFailedCount > 0) {
      _logger.w(
        '同步完成，但存在 ${_statistics.nonRetryableFailedCount} 个不可重试的失败项'
      );
      // 不抛出异常，不触发重试
    }
  }

  /// 处理单个同步项
  ///
  /// 将本地变更推送到服务器，处理冲突（服务器优先）
  ///
  /// Requirements: 6.2
  Future<void> _processSyncItem(SyncQueueItemData item) async {
    _logger.d('处理同步项: ${item.entityType}/${item.entityId} (${item.operation})');

    // 检查 API Client 可用性 (Requirement 6.2)
    final apiClient = _clientMonitor.client;
    if (apiClient == null) {
      // 抛出异常，让上层保留队列项
      throw ClientUnavailableException();
    }

    // 解析 payload
    final payload = json.decode(item.payload) as Map<String, dynamic>;
    
    // 获取基准更新时间（用于冲突检测）
    final baseUpdatedAt = payload['updatedAt'] != null
        ? DateTime.tryParse(payload['updatedAt'] as String)
        : null;

    // 构建推送项
    final pushItem = SyncPushItem(
      localId: item.entityId,
      entityType: item.entityType,
      operation: _operationToString(item.operation),
      payload: payload,
      baseUpdatedAt: baseUpdatedAt,
    );

    // 调用 API 推送
    final results = await apiClient.pushChanges([pushItem]);
    
    if (results.isEmpty) {
      throw Exception('服务器未返回推送结果');
    }

    final result = results.first;

    if (result.isSuccess) {
      _logger.d('同步项 ${item.entityId} 推送成功');
      
      // 如果是 create 操作，可能需要更新本地 ID
      // 这里暂时不处理，因为我们使用 UUID 作为主键
      return;
    }

    if (result.isConflict) {
      _logger.w('同步项 ${item.entityId} 发生冲突，使用服务器版本覆盖');
      
      // 服务器优先：用服务器版本覆盖本地
      if (result.serverVersion == null) {
        // 服务器未返回版本数据，标记为失败等待重试
        throw Exception('冲突处理失败：服务器未返回版本数据');
      }
      await _handleConflict(item.entityType, result.serverVersion);
      return;
    }

    // 其他错误
    throw Exception(result.errorMessage ?? '推送失败');
  }

  /// 处理冲突（服务器优先策略）
  Future<void> _handleConflict(
    String entityType,
    Map<String, dynamic>? serverVersion,
  ) async {
    if (serverVersion == null) {
      _logger.w('冲突处理：服务器未返回版本数据');
      return;
    }

    switch (entityType) {
      case 'customers':
        final customer = ServerDelta.parseCustomer(serverVersion);
        await _db.customerDao.upsertCustomer(customer);
        break;
      case 'clues':
        final clue = ServerDelta.parseClue(serverVersion);
        await _db.clueDao.upsertClue(clue);
        break;
      case 'follow_records':
        final record = ServerDelta.parseFollowRecord(serverVersion);
        await _db.followRecordDao.upsertFollowRecord(record);
        break;
      default:
        _logger.w('未知实体类型: $entityType');
    }
  }

  /// 将操作枚举转换为字符串
  String _operationToString(SyncOperation operation) {
    switch (operation) {
      case SyncOperation.create:
        return 'create';
      case SyncOperation.update:
        return 'update';
      case SyncOperation.delete:
        return 'delete';
    }
  }

  /// 拉取服务器增量数据
  ///
  /// 实现增量同步逻辑：
  /// 1. 调用 API 获取 lastSyncedAt 之后的变更数据
  /// 2. 先删除服务器标记为删除的数据
  /// 3. 再 upsert 更新/新增的数据（服务器优先）
  ///
  /// Requirements: 6.2
  Future<void> _pullServerChanges() async {
    _logger.d('开始拉取服务器数据...');

    // 检查 API Client 可用性
    final apiClient = _clientMonitor.client;
    if (apiClient == null) {
      _logger.d('API Client 不可用，跳过服务器数据拉取');
      _emit(_currentState.copyWith(progress: 1.0));
      return;
    }

    try {
      // 1. 调用 API 获取增量数据
      final delta = await apiClient.pullChanges(_lastSyncedAt);

      // 如果没有变更，直接更新时间戳并持久化
      if (delta.isEmpty) {
        _logger.d('服务器无新数据');
        await _saveLastSyncTime(delta.serverTimestamp);
        _emit(_currentState.copyWith(progress: 1.0));
        return;
      }

      _logger.i('收到服务器增量: '
          '${delta.customers.length} 客户更新, '
          '${delta.deletedCustomerIds.length} 客户删除, '
          '${delta.clues.length} 线索更新, '
          '${delta.deletedClueIds.length} 线索删除, '
          '${delta.followRecords.length} 跟进记录更新, '
          '${delta.deletedFollowRecordIds.length} 跟进记录删除');

      // 2. 在事务中处理所有变更（服务器优先策略）
      await _db.transaction(() async {
        // 先删除（避免删除后又被 upsert 回来）
        await _db.customerDao.deleteAllByIds(delta.deletedCustomerIds);
        await _db.clueDao.deleteAllByIds(delta.deletedClueIds);
        await _db.followRecordDao.deleteAllByIds(delta.deletedFollowRecordIds);

        // 再 upsert（服务器版本覆盖本地）
        if (delta.customers.isNotEmpty) {
          await _db.customerDao.upsertCustomers(delta.customers);
        }
        if (delta.clues.isNotEmpty) {
          await _db.clueDao.upsertClues(delta.clues);
        }
        if (delta.followRecords.isNotEmpty) {
          await _db.followRecordDao.upsertFollowRecords(delta.followRecords);
        }
      });

      // 3. 立即持久化服务器时间戳（避免崩溃后重复拉取）
      await _saveLastSyncTime(delta.serverTimestamp);

      _emit(_currentState.copyWith(progress: 1.0));
      _logger.d('服务器数据拉取完成');
    } catch (e) {
      _logger.e('拉取服务器数据失败: $e');
      rethrow;
    }
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
    _clientMonitor.removeListener(_onClientAvailabilityChanged);
    await _connectivitySub?.cancel();
    await _pendingCountSub?.cancel();
    await _fatalCountSub?.cancel();
    await _stateController.close();
    await _notificationController.close();
  }
}
