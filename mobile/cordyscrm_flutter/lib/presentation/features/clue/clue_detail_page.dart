import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/clue.dart';
import '../../theme/app_theme.dart';
import '../follow/widgets/follow_record_form.dart';
import 'clue_provider.dart';

/// 线索详情页面
class ClueDetailPage extends ConsumerWidget {
  const ClueDetailPage({super.key, required this.clueId});

  final String clueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clueAsync = ref.watch(clueDetailProvider(clueId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('线索详情'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showMoreOptions(context, ref),
          ),
        ],
      ),
      body: clueAsync.when(
        data: (clue) {
          if (clue == null) return const Center(child: Text('线索不存在'));
          return _ClueDetailContent(clue: clue);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
              const SizedBox(height: 16),
              Text('加载失败: $err'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(clueDetailProvider(clueId)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: clueAsync.hasValue && clueAsync.value != null
          ? _BottomActionBar(clue: clueAsync.value!, ref: ref)
          : null,
    );
  }

  void _showMoreOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
              title: const Text('删除线索', style: TextStyle(color: AppTheme.errorColor)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除该线索吗？此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final repo = ref.read(clueRepositoryProvider);
              await repo.deleteClue(clueId);
              ref.invalidate(cluePagingControllerProvider);
              if (context.mounted) context.pop();
            },
            child: const Text('删除', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }
}


/// 线索详情内容
class _ClueDetailContent extends StatelessWidget {
  const _ClueDetailContent({required this.clue});

  final Clue clue;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _ClueInfoCard(clue: clue),
          const SizedBox(height: 12),
          _ClueDetailCard(clue: clue),
        ],
      ),
    );
  }
}

/// 线索信息卡片
class _ClueInfoCard extends StatelessWidget {
  const _ClueInfoCard({required this.clue});

  final Clue clue;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _getStatusColor(clue.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      clue.name.isNotEmpty ? clue.name[0] : '?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(clue.status),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clue.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      _StatusChip(status: clue.status, statusText: clue.statusText),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            _InfoRow(icon: Icons.phone_outlined, label: '电话', value: clue.phone ?? '未设置', isPhone: true),
            _InfoRow(icon: Icons.email_outlined, label: '邮箱', value: clue.email ?? '未设置'),
            _InfoRow(icon: Icons.source_outlined, label: '来源', value: clue.source ?? '未设置'),
          ],
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

/// 线索详情卡片
class _ClueDetailCard extends StatelessWidget {
  const _ClueDetailCard({required this.clue});

  final Clue clue;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('详细信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _DetailItem(label: '负责人', value: clue.owner ?? '未分配'),
            _DetailItem(label: '备注', value: clue.remark ?? '无'),
            _DetailItem(
              label: '创建时间',
              value: clue.createdAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(clue.createdAt!) : '未知',
            ),
            _DetailItem(
              label: '更新时间',
              value: clue.updatedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(clue.updatedAt!) : '未知',
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部操作栏
class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({required this.clue, required this.ref});

  final Clue clue;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.dividerColor)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ActionButton(
              icon: Icons.edit_outlined,
              label: '编辑',
              onTap: () => context.push('/clues/edit/${clue.id}'),
            ),
            _ActionButton(
              icon: Icons.add_comment_outlined,
              label: '跟进',
              onTap: () => _showAddFollowSheet(context),
            ),
            if (clue.canConvert)
              _ActionButton(
                icon: Icons.transform,
                label: '转客户',
                onTap: () => _convertToCustomer(context),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddFollowSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => FollowRecordForm(
        clueId: clue.id,
        onSuccess: () => Navigator.pop(context),
      ),
    );
  }

  void _convertToCustomer(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('转化为客户'),
        content: const Text('确定要将此线索转化为客户吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final customerId = await ref.read(clueFormProvider.notifier).convertToCustomer(clue.id);
              if (customerId != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('转化成功'), backgroundColor: AppTheme.successColor),
                );
                ref.invalidate(clueDetailProvider(clue.id));
                ref.invalidate(cluePagingControllerProvider);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: AppTheme.primaryColor),
      label: Text(label, style: const TextStyle(color: AppTheme.primaryColor)),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.statusText});

  final String status;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(statusText, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value, this.isPhone = false});

  final IconData icon;
  final String label;
  final String value;
  final bool isPhone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textTertiary),
          const SizedBox(width: 12),
          SizedBox(width: 60, child: Text(label, style: const TextStyle(color: AppTheme.textSecondary))),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: isPhone && value != '未设置' ? AppTheme.primaryColor : AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: AppTheme.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(color: AppTheme.textPrimary))),
        ],
      ),
    );
  }
}
