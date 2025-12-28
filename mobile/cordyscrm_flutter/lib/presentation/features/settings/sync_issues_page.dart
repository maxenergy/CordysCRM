import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/sources/local/tables/tables.dart';
import '../../../services/sync/sync_provider.dart';
import '../../theme/app_theme.dart';

/// Fatal Error 项列表 Provider
final fatalItemsProvider = FutureProvider.autoDispose((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.syncQueueDao.getFatalItems();
});

/// 同步问题页面
///
/// 显示所有达到最大重试次数的同步项（Fatal Error）
/// 用户可以手动重试这些项
///
/// Requirements: 7.5
class SyncIssuesPage extends ConsumerWidget {
  const SyncIssuesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fatalItemsAsync = ref.watch(fatalItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('同步问题'),
      ),
      body: fatalItemsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: AppTheme.successColor,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '没有同步问题',
                    style: TextStyle(fontSize: 18),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '致命错误',
                              style: TextStyle(
                                color: AppTheme.errorColor,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatDateTime(item.updatedAt),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${_getEntityName(item.entityType)} (${_getOperationName(item.operation)})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.errorMessage ?? '未知错误',
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () async {
                              await ref
                                  .read(syncServiceProvider)
                                  .retryFatalItem(item.id);
                              ref.invalidate(fatalItemsProvider);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('正在重试...'),
                                    backgroundColor: AppTheme.successColor,
                                  ),
                                );
                              }
                            },
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('加载失败: $err'),
            ],
          ),
        ),
      ),
    );
  }

  String _getEntityName(String type) {
    switch (type) {
      case 'customers':
        return '客户';
      case 'clues':
        return '线索';
      case 'opportunities':
        return '商机';
      case 'follow_records':
        return '跟进记录';
      default:
        return type;
    }
  }

  String _getOperationName(SyncOperation op) {
    switch (op) {
      case SyncOperation.create:
        return '创建';
      case SyncOperation.update:
        return '更新';
      case SyncOperation.delete:
        return '删除';
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
