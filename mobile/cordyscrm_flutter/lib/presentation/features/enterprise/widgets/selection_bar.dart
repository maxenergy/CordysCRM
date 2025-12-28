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

    // Debug logging
    debugPrint('[SelectionBar] build() 被调用');
    debugPrint('[SelectionBar] selectedCount=$selectedCount, isAllSelected=$isAllSelected');

    // 计算 Checkbox 的状态
    // true = 全选, false = 未选, null = 部分选择
    final bool? checkboxState;
    if (selectedCount == 0) {
      checkboxState = false;
    } else if (isAllSelected) {
      checkboxState = true;
    } else {
      checkboxState = null; // tristate 为 true 时，null 会显示为横杠
    }

    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false, // 禁用顶部内边距，防止状态栏高度影响底部栏布局
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 左侧：取消按钮和全选 Checkbox
              Row(
                children: [
                  // 取消按钮
                  TextButton(
                    onPressed: onCancel,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  // 全选 Checkbox 区域
                  InkWell(
                    onTap: onSelectAll,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: checkboxState,
                              tristate: true, // 开启三态支持
                              onChanged: (_) => onSelectAll(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '全选',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // 右侧：批量导入按钮
              FilledButton.icon(
                onPressed: selectedCount > 0 ? onBatchImport : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.cloud_upload_outlined, size: 20),
                label: Text(
                  '批量导入 ($selectedCount)',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
