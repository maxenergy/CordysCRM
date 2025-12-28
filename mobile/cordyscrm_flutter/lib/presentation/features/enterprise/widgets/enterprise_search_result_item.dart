import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/enterprise.dart';
import '../enterprise_provider.dart';

/// 企业搜索结果项 (ConsumerWidget版本)
///
/// 这个组件现在通过 Riverpod 自我管理与选择相关的状态和交互,
/// 从而解决了父组件中的闭包陷阱问题。
class EnterpriseSearchResultItem extends ConsumerWidget {
  const EnterpriseSearchResultItem({
    super.key,
    required this.enterprise,
    required this.onTap,
  });

  final Enterprise enterprise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final searchState = ref.watch(enterpriseSearchProvider);
    final isSelectionMode = searchState.isSelectionMode;
    final isSelected = searchState.selectedIds.contains(enterprise.creditCode);

    void handleSelectionWithFeedback() {
      final error = ref
          .read(enterpriseSearchProvider.notifier)
          .toggleSelection(enterprise.creditCode);
      
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }

    void handleTap() {
      // 如果在选择模式下，单击是切换选择
      if (isSelectionMode) {
        handleSelectionWithFeedback();
      } else {
        // 否则，执行传入的onTap回调（例如，导航到详情页）
        onTap();
      }
    }

    void handleLongPress() {
      // 只有在非选择模式下，长按才进入选择模式
      if (!isSelectionMode) {
        FocusScope.of(context).unfocus(); // 关闭键盘
        ref
            .read(enterpriseSearchProvider.notifier)
            .enterSelectionMode(initialSelectedId: enterprise.creditCode);
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: handleTap,
        onLongPress: handleLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 在选择模式下显示复选框
              if (isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Checkbox(
                    value: isSelected,
                    // 本地企业不允许选择
                    onChanged: enterprise.isLocal
                        ? null
                        : (selected) {
                            handleSelectionWithFeedback();
                          },
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 企业名称和状态
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            enterprise.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildSourceChip(context),
                        const SizedBox(width: 4),
                        _buildStatusChip(context),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // 信用代码
                    if (enterprise.creditCode.isNotEmpty)
                      _buildInfoRow(
                        context,
                        Icons.badge_outlined,
                        '信用代码',
                        enterprise.creditCode,
                      ),

                    // 法定代表人
                    if (enterprise.legalPerson.isNotEmpty)
                      _buildInfoRow(
                        context,
                        Icons.person_outline,
                        '法人',
                        enterprise.legalPerson,
                      ),

                    // 行业
                    if (enterprise.industry.isNotEmpty)
                      _buildInfoRow(
                        context,
                        Icons.category_outlined,
                        '行业',
                        enterprise.industry,
                      ),

                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建来源标签
  Widget _buildSourceChip(BuildContext context) {
    // 本地企业显示"已导入"
    if (enterprise.isLocal) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
        ),
        child: const Text(
          '已导入',
          style: TextStyle(
            fontSize: 12,
            color: Colors.blue,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
    
    final (color, label) = switch (enterprise.source) {
      'qcc' => (Colors.green, '企查查'),
      'iqicha' => (Colors.purple, '爱企查'),
      _ => (Colors.grey, '未知'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// 构建状态标签
  Widget _buildStatusChip(BuildContext context) {
    final isActive = enterprise.isActive;
    final color = isActive ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        enterprise.status.isNotEmpty ? enterprise.status : '未知',
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
