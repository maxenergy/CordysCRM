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

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 左侧：取消按钮和全选 Checkbox
                Row(
                  children: [
                    // 取消按钮
                    TextButton(
                      onPressed: onCancel,
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 16),
                    // 全选 Checkbox 区域
                    InkWell(
                      onTap: onSelectAll,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        child: Row(
                          children: [
                            Checkbox(
                              value: checkboxState,
                              tristate: true, // 开启三态支持
                              onChanged: (_) => onSelectAll(),
                            ),
                            const SizedBox(width: 4),
                            const Text('全选'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // 右侧：批量导入按钮
                FilledButton.icon(
                  onPressed: selectedCount > 0 ? onBatchImport : null,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text('批量导入 ($selectedCount)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
