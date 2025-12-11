import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/sync/sync_provider.dart';
import '../../services/sync/sync_state.dart';

// 使用别名避免与数据库 SyncStatus 冲突
typedef SyncStatus = SyncServiceStatus;

/// 同步状态指示器
///
/// 显示当前同步状态的图标按钮，支持：
/// - 不同状态显示不同图标和颜色
/// - 显示待同步数量徽章
/// - 点击手动触发同步
/// - 同步中显示旋转动画
class SyncStatusIndicator extends ConsumerStatefulWidget {
  const SyncStatusIndicator({
    super.key,
    this.size = 24.0,
    this.showBadge = true,
    this.showTooltip = true,
  });

  /// 图标大小
  final double size;

  /// 是否显示待同步数量徽章
  final bool showBadge;

  /// 是否显示提示文字
  final bool showTooltip;

  @override
  ConsumerState<SyncStatusIndicator> createState() =>
      _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends ConsumerState<SyncStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncNotifierProvider);

    // 控制旋转动画
    if (syncState.status == SyncStatus.syncing) {
      _rotationController.repeat();
    } else {
      _rotationController.stop();
      _rotationController.reset();
    }

    final iconData = _getIconData(syncState.status);
    final iconColor = _getIconColor(syncState.status);
    final tooltipMessage = _getTooltipMessage(syncState);

    Widget iconWidget = Icon(
      iconData,
      size: widget.size,
      color: iconColor,
    );

    // 同步中添加旋转动画
    if (syncState.status == SyncStatus.syncing) {
      iconWidget = RotationTransition(
        turns: _rotationController,
        child: iconWidget,
      );
    }

    Widget button = IconButton(
      icon: iconWidget,
      onPressed: _onPressed,
      tooltip: widget.showTooltip ? tooltipMessage : null,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: widget.size + 16,
        minHeight: widget.size + 16,
      ),
    );

    // 添加待同步数量徽章
    if (widget.showBadge && syncState.pendingCount > 0) {
      button = Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned(
            right: 0,
            top: 0,
            child: _buildBadge(syncState.pendingCount),
          ),
        ],
      );
    }

    return button;
  }

  /// 获取状态对应的图标
  IconData _getIconData(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return Icons.cloud_done_outlined;
      case SyncStatus.syncing:
        return Icons.sync;
      case SyncStatus.succeeded:
        return Icons.cloud_done;
      case SyncStatus.failed:
        return Icons.cloud_off;
      case SyncStatus.offline:
        return Icons.signal_wifi_off;
    }
  }

  /// 获取状态对应的颜色
  Color _getIconColor(SyncStatus status) {
    final theme = Theme.of(context);
    switch (status) {
      case SyncStatus.idle:
        return theme.colorScheme.onSurfaceVariant;
      case SyncStatus.syncing:
        return theme.colorScheme.primary;
      case SyncStatus.succeeded:
        return Colors.green;
      case SyncStatus.failed:
        return theme.colorScheme.error;
      case SyncStatus.offline:
        return Colors.orange;
    }
  }

  /// 获取提示文字
  String _getTooltipMessage(SyncState state) {
    switch (state.status) {
      case SyncStatus.idle:
        if (state.pendingCount > 0) {
          return '${state.pendingCount} 项待同步，点击同步';
        }
        return '数据已同步';
      case SyncStatus.syncing:
        return '正在同步...';
      case SyncStatus.succeeded:
        return '同步成功';
      case SyncStatus.failed:
        return state.error ?? '同步失败，点击重试';
      case SyncStatus.offline:
        return '当前离线，${state.pendingCount} 项待同步';
    }
  }

  /// 构建数量徽章
  Widget _buildBadge(int count) {
    final displayCount = count > 99 ? '99+' : count.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use - withValues 在某些 Flutter 版本不可用
            color: Colors.black.withOpacity(0.2),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      constraints: const BoxConstraints(minWidth: 18),
      child: Text(
        displayCount,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// 点击处理
  void _onPressed() {
    final syncState = ref.read(syncNotifierProvider);

    // 离线状态下提示用户
    if (syncState.status == SyncStatus.offline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('当前离线，请检查网络连接'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // 同步中不重复触发
    if (syncState.status == SyncStatus.syncing) {
      return;
    }

    // 触发同步
    ref.read(syncNotifierProvider.notifier).triggerSync();

    // 显示提示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('开始同步...'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}

/// 同步状态卡片
///
/// 用于设置页面或详情页面展示完整的同步状态信息
class SyncStatusCard extends ConsumerWidget {
  const SyncStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncNotifierProvider);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SyncStatusIndicator(size: 28, showBadge: false),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getStatusTitle(syncState.status),
                        style: theme.textTheme.titleMedium,
                      ),
                      if (syncState.lastSyncedAt != null)
                        Text(
                          '上次同步: ${_formatDateTime(syncState.lastSyncedAt!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (syncState.pendingCount > 0) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: syncState.progress,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 8),
              Text(
                '${syncState.pendingCount} 项待同步',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (syncState.error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 16,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        syncState.error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: syncState.status == SyncStatus.syncing ||
                        syncState.status == SyncStatus.offline
                    ? null
                    : () => ref.read(syncNotifierProvider.notifier).triggerSync(),
                child: Text(
                  syncState.status == SyncStatus.syncing ? '同步中...' : '立即同步',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusTitle(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return '数据同步';
      case SyncStatus.syncing:
        return '正在同步';
      case SyncStatus.succeeded:
        return '同步成功';
      case SyncStatus.failed:
        return '同步失败';
      case SyncStatus.offline:
        return '离线模式';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes} 分钟前';
    } else if (diff.inDays < 1) {
      return '${diff.inHours} 小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} 天前';
    } else {
      return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}
