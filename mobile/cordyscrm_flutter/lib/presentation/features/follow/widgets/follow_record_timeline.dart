import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../domain/entities/follow_record.dart';
import '../../../theme/app_theme.dart';

/// 跟进记录时间线组件
class FollowRecordTimeline extends StatelessWidget {
  const FollowRecordTimeline({
    super.key,
    required this.records,
    this.onAddPressed,
  });

  final List<FollowRecord> records;
  final VoidCallback? onAddPressed;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        final isLast = index == records.length - 1;
        return _FollowRecordItem(record: record, isLast: isLast);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 48, color: AppTheme.textTertiary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text('暂无跟进记录', style: TextStyle(color: AppTheme.textSecondary)),
          if (onAddPressed != null) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onAddPressed,
              icon: const Icon(Icons.add),
              label: const Text('添加跟进'),
            ),
          ],
        ],
      ),
    );
  }
}

class _FollowRecordItem extends StatelessWidget {
  const _FollowRecordItem({required this.record, required this.isLast});

  final FollowRecord record;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 时间线
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _getTypeColor().withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_getTypeIcon(), size: 16, color: _getTypeColor()),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppTheme.borderColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 内容
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题行
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getTypeColor().withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          record.followTypeText,
                          style: TextStyle(fontSize: 11, color: _getTypeColor(), fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDateTime(record.followAt),
                        style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                      ),
                      const Spacer(),
                      if (record.createdBy != null)
                        Text(
                          record.createdBy!,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 内容
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Text(
                      record.content,
                      style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, height: 1.5),
                    ),
                  ),
                  // 附件（如果有）
                  if (record.images != null && record.images!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: record.images!.map((url) => _ImageThumbnail(url: url)).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon() {
    switch (record.followType) {
      case FollowRecord.typePhone:
        return Icons.phone;
      case FollowRecord.typeVisit:
        return Icons.place;
      case FollowRecord.typeWechat:
        return Icons.chat;
      case FollowRecord.typeEmail:
        return Icons.email;
      default:
        return Icons.note;
    }
  }

  Color _getTypeColor() {
    switch (record.followType) {
      case FollowRecord.typePhone:
        return AppTheme.primaryColor;
      case FollowRecord.typeVisit:
        return AppTheme.successColor;
      case FollowRecord.typeWechat:
        return Colors.green;
      case FollowRecord.typeEmail:
        return AppTheme.warningColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays == 0) {
      return '今天 ${DateFormat('HH:mm').format(dateTime)}';
    } else if (diff.inDays == 1) {
      return '昨天 ${DateFormat('HH:mm').format(dateTime)}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return DateFormat('MM-dd HH:mm').format(dateTime);
    }
  }
}

class _ImageThumbnail extends StatelessWidget {
  const _ImageThumbnail({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: const Icon(Icons.image, color: AppTheme.textTertiary),
    );
  }
}
