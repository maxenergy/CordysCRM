import 'package:logger/logger.dart';

import '../../data/sources/local/app_database.dart';
import '../../data/sources/local/tables/tables.dart';

/// 负责从不一致的同步状态中恢复
///
/// 主要功能：
/// 1. 重置长时间处于 InProgress 状态的队列项（防止应用崩溃导致的状态卡死）
/// 2. 验证同步队列完整性（检测重复项和必填字段缺失）
class SyncStateRecovery {
  final AppDatabase _db;
  final Logger _logger;

  SyncStateRecovery(this._db, this._logger);

  /// 重置长时间处于 InProgress 状态的队列项
  ///
  /// [staleThreshold] 定义过期的阈值，默认为 5 分钟
  /// 返回重置的项数
  ///
  /// 设计决策：
  /// - 保留 attemptCount：有助于后续判断是否为"顽固"错误
  /// - 保留 errorType：有助于调试，直到下一次尝试覆盖
  Future<int> resetStaleInProgressItems({
    Duration staleThreshold = const Duration(minutes: 5),
  }) async {
    final cutoff = DateTime.now().subtract(staleThreshold);
    final staleItems = await _db.syncQueueDao.findInProgressBefore(cutoff);

    if (staleItems.isEmpty) return 0;

    _logger.w('发现 ${staleItems.length} 个过期的处理中同步项，正在重置为待处理状态...');

    int resetCount = 0;
    for (final item in staleItems) {
      try {
        // 重置为 pending，保留 attemptCount 和 error 信息以便追踪
        await _db.syncQueueDao.updateItemStatus(
          item.id,
          SyncQueueItemStatus.pending,
        );
        _logger.w(
          '重置过期同步项: ID=${item.id}, '
          'entity=${item.entityType}/${item.entityId}, '
          'operation=${item.operation}, '
          'attempts=${item.attemptCount}, '
          'lastUpdate=${item.updatedAt}',
        );
        resetCount++;
      } catch (e) {
        _logger.e('重置同步项 ${item.id} 失败: $e');
      }
    }

    if (resetCount > 0) {
      _logger.i('成功重置了 $resetCount 个过期的同步项');
    }

    return resetCount;
  }

  /// 验证同步队列完整性
  ///
  /// 检查：
  /// 1. 重复的 pending/in-progress 项（同一实体）
  /// 2. 必填字段缺失（entityId, entityType）
  ///
  /// 记录警告但不抛出异常（避免阻塞服务启动）
  ///
  /// 返回 true 表示队列完整性良好，false 表示发现问题
  Future<bool> validateQueueIntegrity() async {
    bool isValid = true;
    _logger.d('开始验证同步队列完整性...');

    try {
      final pendingItems = await _db.syncQueueDao.getPendingItems();
      // 获取所有 inProgress 项（通过传入未来时间）
      final inProgressItems = await _db.syncQueueDao.findInProgressBefore(
        DateTime.now().add(const Duration(days: 365)),
      );

      final allActiveItems = [...pendingItems, ...inProgressItems];
      final seenEntities = <String>{}; // format: "entityType:entityId"

      for (final item in allActiveItems) {
        final key = '${item.entityType}:${item.entityId}';

        // 检查必填字段
        if (item.entityId.isEmpty || item.entityType.isEmpty) {
          _logger.w(
            '完整性检查失败: 同步项 ${item.id} 缺少 entityId 或 entityType',
          );
          isValid = false;
        }

        // 检查重复项
        if (seenEntities.contains(key)) {
          _logger.w(
            '完整性检查警告: 实体 $key 存在多个活跃同步项 '
            '(ID: ${item.id}, status: ${item.status})',
          );
          isValid = false;
        } else {
          seenEntities.add(key);
        }
      }

      if (isValid) {
        _logger.d('同步队列完整性验证通过 (检查了 ${allActiveItems.length} 个活跃项)');
      } else {
        _logger.w('同步队列完整性验证发现问题，请检查日志');
      }
    } catch (e) {
      _logger.e('验证队列完整性时发生错误: $e');
      return false;
    }

    return isValid;
  }
}
