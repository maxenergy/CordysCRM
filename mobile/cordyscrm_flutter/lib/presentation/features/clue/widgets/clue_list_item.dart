import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../domain/entities/clue.dart';
import '../../../theme/app_theme.dart';

/// 线索列表项组件
class ClueListItem extends StatelessWidget {
  const ClueListItem({
    super.key,
    required this.clue,
    required this.onTap,
  });

  final Clue clue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 头像
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _getStatusColor(clue.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    clue.name.isNotEmpty ? clue.name[0] : '?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(clue.status),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            clue.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _StatusTag(status: clue.status, statusText: clue.statusText),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (clue.phone != null) ...[
                          const Icon(Icons.phone_outlined, size: 14, color: AppTheme.textTertiary),
                          const SizedBox(width: 4),
                          Text(
                            clue.phone!,
                            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (clue.source != null) ...[
                          const Icon(Icons.source_outlined, size: 14, color: AppTheme.textTertiary),
                          const SizedBox(width: 4),
                          Text(
                            clue.source!,
                            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (clue.owner != null) ...[
                          const Icon(Icons.person_outline, size: 14, color: AppTheme.textTertiary),
                          const SizedBox(width: 4),
                          Text(
                            clue.owner!,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (clue.createdAt != null) ...[
                          const Icon(Icons.access_time, size: 14, color: AppTheme.textTertiary),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MM-dd HH:mm').format(clue.createdAt!),
                            style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case Clue.statusNew:
        return AppTheme.primaryColor;
      case Clue.statusFollowing:
        return AppTheme.warningColor;
      case Clue.statusConverted:
        return AppTheme.successColor;
      case Clue.statusInvalid:
        return AppTheme.textTertiary;
      default:
        return AppTheme.textSecondary;
    }
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.status, required this.statusText});

  final String status;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        statusText,
        style: TextStyle(fontSize: 11, color: _getColor(), fontWeight: FontWeight.w500),
      ),
    );
  }

  Color _getColor() {
    switch (status) {
      case Clue.statusNew:
        return AppTheme.primaryColor;
      case Clue.statusFollowing:
        return AppTheme.warningColor;
      case Clue.statusConverted:
        return AppTheme.successColor;
      case Clue.statusInvalid:
        return AppTheme.textTertiary;
      default:
        return AppTheme.textSecondary;
    }
  }
}
