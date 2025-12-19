import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/opportunity.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../follow/widgets/follow_record_form.dart';
import 'opportunity_provider.dart';

/// 商机详情页面
class OpportunityDetailPage extends ConsumerWidget {
  const OpportunityDetailPage({super.key, required this.opportunityId});

  final String opportunityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oppAsync = ref.watch(opportunityDetailProvider(opportunityId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('商机详情'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showMoreOptions(context, ref),
          ),
        ],
      ),
      body: oppAsync.when(
        data: (opp) {
          if (opp == null) return const Center(child: Text('商机不存在'));
          return _OpportunityDetailContent(opportunity: opp, ref: ref);
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
                onPressed: () => ref.invalidate(opportunityDetailProvider(opportunityId)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 操作按钮栏
          if (oppAsync.hasValue && oppAsync.value != null)
            _BottomActionBar(opportunity: oppAsync.value!, ref: ref),
          // 主导航栏
          const AppBottomNavBar(currentModule: ModuleIndex.opportunity),
        ],
      ),
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
              title: const Text('删除商机', style: TextStyle(color: AppTheme.errorColor)),
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
        content: const Text('确定要删除该商机吗？此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final repo = ref.read(opportunityRepositoryProvider);
              await repo.deleteOpportunity(opportunityId);
              ref.invalidate(opportunityPagingControllerProvider);
              if (context.mounted) context.pop();
            },
            child: const Text('删除', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }
}


/// 商机详情内容
class _OpportunityDetailContent extends StatelessWidget {
  const _OpportunityDetailContent({required this.opportunity, required this.ref});

  final Opportunity opportunity;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _OpportunityInfoCard(opportunity: opportunity),
          const SizedBox(height: 12),
          _StageProgressCard(opportunity: opportunity, ref: ref),
          const SizedBox(height: 12),
          _OpportunityDetailCard(opportunity: opportunity),
        ],
      ),
    );
  }
}

/// 商机信息卡片
class _OpportunityInfoCard extends StatelessWidget {
  const _OpportunityInfoCard({required this.opportunity});

  final Opportunity opportunity;

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
                Expanded(
                  child: Text(opportunity.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                _StageChip(stage: opportunity.stage, stageText: opportunity.stageText),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            _InfoRow(icon: Icons.business, label: '客户', value: opportunity.customerName ?? '未关联'),
            _InfoRow(
              icon: Icons.attach_money,
              label: '金额',
              value: opportunity.amount != null ? '¥${_formatAmount(opportunity.amount!)}' : '未设置',
              valueColor: AppTheme.primaryColor,
            ),
            _InfoRow(
              icon: Icons.event,
              label: '预计成交',
              value: opportunity.expectedCloseDate != null
                  ? DateFormat('yyyy-MM-dd').format(opportunity.expectedCloseDate!)
                  : '未设置',
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 10000) return '${(amount / 10000).toStringAsFixed(2)}万';
    return amount.toStringAsFixed(2);
  }
}

/// 阶段进度卡片
class _StageProgressCard extends StatelessWidget {
  const _StageProgressCard({required this.opportunity, required this.ref});

  final Opportunity opportunity;
  final WidgetRef ref;

  static const _stages = [
    (Opportunity.stageInitial, '初步接触'),
    (Opportunity.stageQualified, '需求确认'),
    (Opportunity.stageProposal, '方案报价'),
    (Opportunity.stageNegotiation, '商务谈判'),
  ];

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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('阶段进度', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                if (opportunity.probability != null)
                  Text('赢率 ${opportunity.probability}%', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: _stages.asMap().entries.map((entry) {
                final index = entry.key;
                final (stage, label) = entry.value;
                final isActive = opportunity.stageIndex >= index;
                final isCurrent = opportunity.stage == stage;
                
                return Expanded(
                  child: GestureDetector(
                    onTap: opportunity.canAdvance ? () => _advanceStage(context, stage) : null,
                    child: Column(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isActive ? AppTheme.primaryColor : AppTheme.borderColor,
                            shape: BoxShape.circle,
                            border: isCurrent ? Border.all(color: AppTheme.primaryColor, width: 3) : null,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(color: isActive ? Colors.white : AppTheme.textTertiary, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: TextStyle(fontSize: 10, color: isActive ? AppTheme.primaryColor : AppTheme.textTertiary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _advanceStage(BuildContext context, String newStage) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('推进阶段'),
        content: Text('确定要将商机推进到"${_getStageText(newStage)}"阶段吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref.read(opportunityFormProvider.notifier).advanceStage(opportunity.id, newStage);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('阶段推进成功'), backgroundColor: AppTheme.successColor),
                );
                ref.invalidate(opportunityDetailProvider(opportunity.id));
                ref.invalidate(opportunityPagingControllerProvider);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  String _getStageText(String stage) {
    switch (stage) {
      case Opportunity.stageInitial: return '初步接触';
      case Opportunity.stageQualified: return '需求确认';
      case Opportunity.stageProposal: return '方案报价';
      case Opportunity.stageNegotiation: return '商务谈判';
      default: return stage;
    }
  }
}

/// 商机详情卡片
class _OpportunityDetailCard extends StatelessWidget {
  const _OpportunityDetailCard({required this.opportunity});

  final Opportunity opportunity;

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
            _DetailItem(label: '负责人', value: opportunity.owner ?? '未分配'),
            _DetailItem(label: '备注', value: opportunity.remark ?? '无'),
            _DetailItem(
              label: '创建时间',
              value: opportunity.createdAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(opportunity.createdAt!) : '未知',
            ),
            _DetailItem(
              label: '更新时间',
              value: opportunity.updatedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(opportunity.updatedAt!) : '未知',
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部操作栏
class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({required this.opportunity, required this.ref});

  final Opportunity opportunity;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    // 移除 SafeArea，因为导航栏会处理底部安全区域
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ActionButton(icon: Icons.edit_outlined, label: '编辑', onTap: () => context.push('/opportunities/edit/${opportunity.id}')),
          _ActionButton(
            icon: Icons.add_comment_outlined,
            label: '跟进',
            onTap: () => _showAddFollowSheet(context),
          ),
          if (opportunity.canAdvance)
            _ActionButton(
              icon: Icons.check_circle_outline,
              label: '赢单',
              onTap: () => _markAsWon(context),
            ),
          if (opportunity.canAdvance)
            _ActionButton(
              icon: Icons.cancel_outlined,
              label: '输单',
              onTap: () => _markAsLost(context),
            ),
        ],
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
        customerId: opportunity.customerId,
        onSuccess: () => Navigator.pop(context),
      ),
    );
  }

  void _markAsWon(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('标记赢单'),
        content: const Text('确定要将此商机标记为赢单吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref.read(opportunityFormProvider.notifier).advanceStage(opportunity.id, Opportunity.stageWon);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('恭喜赢单！'), backgroundColor: AppTheme.successColor),
                );
                ref.invalidate(opportunityDetailProvider(opportunity.id));
                ref.invalidate(opportunityPagingControllerProvider);
              }
            },
            child: const Text('确定', style: TextStyle(color: AppTheme.successColor)),
          ),
        ],
      ),
    );
  }

  void _markAsLost(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('标记输单'),
        content: const Text('确定要将此商机标记为输单吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref.read(opportunityFormProvider.notifier).advanceStage(opportunity.id, Opportunity.stageLost);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已标记为输单')));
                ref.invalidate(opportunityDetailProvider(opportunity.id));
                ref.invalidate(opportunityPagingControllerProvider);
              }
            },
            child: const Text('确定', style: TextStyle(color: AppTheme.errorColor)),
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
      icon: Icon(icon, color: AppTheme.primaryColor, size: 20),
      label: Text(label, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 13)),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.stage, required this.stageText});

  final String stage;
  final String stageText;

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(stageText, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }

  Color _getColor() {
    switch (stage) {
      case Opportunity.stageInitial: return AppTheme.textSecondary;
      case Opportunity.stageQualified: return AppTheme.primaryColor;
      case Opportunity.stageProposal: return AppTheme.warningColor;
      case Opportunity.stageNegotiation: return Colors.orange;
      case Opportunity.stageWon: return AppTheme.successColor;
      case Opportunity.stageLost: return AppTheme.errorColor;
      default: return AppTheme.textSecondary;
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value, this.valueColor});

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textTertiary),
          const SizedBox(width: 12),
          SizedBox(width: 70, child: Text(label, style: const TextStyle(color: AppTheme.textSecondary))),
          Expanded(child: Text(value, style: TextStyle(color: valueColor ?? AppTheme.textPrimary, fontWeight: valueColor != null ? FontWeight.w500 : null))),
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
