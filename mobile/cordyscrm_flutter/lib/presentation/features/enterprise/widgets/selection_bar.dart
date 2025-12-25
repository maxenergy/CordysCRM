import 'package:flutter/material.dart';

/// 企业选择模式底部操作栏
class SelectionBar extends StatelessWidget {
  const SelectionBar({
    super.key,
    required this.selectedCount,
    required this.isAllSelected,
    required this.onCancel,
    required this.onSelectAll,
    required this.onBatchImport,
  });

  final int selectedCount;
  final bool isAllSelected;
  final VoidCallback onCancel;
  final VoidCallback onSelectAll;
  final VoidCallback onBatchImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // 取消按钮
            TextButton(
              onPressed: onCancel,
              child: const Text('取消'),
            ),
            const Spacer(),
            // 已选数量
            Text(
              '已选 $selectedCount',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 16),
            // 全选/取消全选按钮
            TextButton(
              onPressed: onSelectAll,
              child: Text(isAllSelected ? '取消全选' : '全选'),
            ),
            const SizedBox(width: 8),
            // 批量导入按钮
            FilledButton(
              onPressed: selectedCount > 0 ? onBatchImport : null,
              child: Text('批量导入 ($selectedCount)'),
            ),
          ],
        ),
      ),
    );
  }
}
