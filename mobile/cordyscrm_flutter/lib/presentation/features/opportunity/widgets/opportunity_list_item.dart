import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../domain/entities/opportunity.dart';
import '../../../theme/app_theme.dart';

/// 商机列表项组件
class OpportunityListItem extends StatelessWidget {
  const OpportunityListItem({
    super.key,
    required this.opportunity,
    required this.onTap,
  });

  final Opportunity opportunity;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                children: [
                  Expanded(
                    child: Text(
                      opportunity.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _StageTag(stage: opportunity.stage, stageText: opportunity.stageText),
                ],
              ),
              const SizedBox(height: 8),
              // 客户和金额
              Row(
                children: [
                  if (opportunity.customerName != null) ...[
                    const Icon(Icons.business, size: 14, color: AppTheme.textTertiary),
                    const SizedBox(width: 4),
                    Text(opportunity.customerName!, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    const SizedBox(width: 16),
                  ],
                  if (opportunity.amount != null) ...[
                    const Icon(Icons.attach_money, size: 14, color: AppTheme.textTertiary),
                    Text(
                      _formatAmount(opportunity.amount!),
                      style: const TextStyle(fontSize: 13, color: AppTheme.primaryColor, fontWeight: FontWeight.w500),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // 阶段进度条
              _StageProgressBar(stageIndex: opportunity.stageIndex, isClosed: opportunity.isClosed),
              const SizedBox(height: 8),
              // 底部信息
              Row(
                children: [
                  if (opportunity.owner != null) ...[
                    const Icon(Icons.person_outline, size: 14, color: AppTheme.textTertiary),
                    const SizedBox(width: 4),
                    Text(opportunity.owner!, style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
                    const SizedBox(width: 12),
                  ],
                  if (opportunity.expectedCloseDate != null) ...[
                    const Icon(Icons.event, size: 14, color: AppTheme.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      '预计 ${DateFormat('MM-dd').format(opportunity.expectedCloseDate!)}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                    ),
                  ],
                  const Spacer(),
                  if (opportunity.probability != null)
                    Text(
                      '${opportunity.probability}%',
                      style: TextStyle(fontSize: 12, color: _getStageColor(opportunity.stage), fontWeight: FontWeight.w500),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 10000) {
      return '${(amount / 10000).toStringAsFixed(1)}万';
    }
    return amount.toStringAsFixed(0);
  }

  Color _getStageColor(String stage) {
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

class _StageTag extends StatelessWidget {
  const _StageTag({required this.stage, required this.stageText});

  final String stage;
  final String stageText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(stageText, style: TextStyle(fontSize: 11, color: _getColor(), fontWeight: FontWeight.w500)),
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

class _StageProgressBar extends StatelessWidget {
  const _StageProgressBar({required this.stageIndex, required this.isClosed});

  final int stageIndex;
  final bool isClosed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (index) {
        final isActive = stageIndex > index || (stageIndex == 4 && index == 3);
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
            decoration: BoxDecoration(
              color: isActive ? AppTheme.primaryColor : AppTheme.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
