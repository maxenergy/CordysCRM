import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../domain/entities/customer.dart';
import '../../../theme/app_theme.dart';

/// 客户列表项组件
class CustomerListItem extends StatelessWidget {
  const CustomerListItem({
    super.key,
    required this.customer,
    required this.onTap,
  });

  final Customer customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastFollowUp = customer.lastFollowUpAt != null
        ? DateFormat('yyyy-MM-dd').format(customer.lastFollowUpAt!)
        : '无';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppTheme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 客户名称
              Text(
                customer.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // 联系人和状态
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 16,
                    color: AppTheme.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '联系人: ${customer.contactPerson ?? '未设置'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _StatusChip(status: customer.status),
                ],
              ),
              const SizedBox(height: 8),

              // 负责人和最近跟进
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '负责人: ${customer.owner ?? '未分配'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textTertiary,
                    ),
                  ),
                  Text(
                    '最近跟进: $lastFollowUp',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 状态标签组件
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '意向客户':
        return AppTheme.warningColor;
      case '成交客户':
        return AppTheme.successColor;
      case '流失客户':
        return AppTheme.errorColor;
      default:
        return AppTheme.primaryColor;
    }
  }
}
