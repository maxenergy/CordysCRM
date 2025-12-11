import 'package:flutter/material.dart';

import '../../../../domain/entities/enterprise.dart';

/// 企业搜索结果项
class EnterpriseSearchResultItem extends StatelessWidget {
  const EnterpriseSearchResultItem({
    super.key,
    required this.enterprise,
    required this.onTap,
  });

  final Enterprise enterprise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
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

              const SizedBox(height: 8),

              // 操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('查看详情'),
                  ),
                ],
              ),
            ],
          ),
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
