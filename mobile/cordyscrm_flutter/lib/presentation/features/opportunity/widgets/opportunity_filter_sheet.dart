import 'package:flutter/material.dart';

import '../../../../domain/repositories/opportunity_repository.dart';
import '../../../theme/app_theme.dart';
import '../opportunity_provider.dart';

/// 商机筛选弹窗
class OpportunityFilterSheet extends StatefulWidget {
  const OpportunityFilterSheet({
    super.key,
    required this.initialQuery,
    required this.onApplyFilter,
  });

  final OpportunityQuery initialQuery;
  final void Function(OpportunityQuery) onApplyFilter;

  @override
  State<OpportunityFilterSheet> createState() => _OpportunityFilterSheetState();
}

class _OpportunityFilterSheetState extends State<OpportunityFilterSheet> {
  late String? _selectedStage;
  late String? _selectedOwner;

  @override
  void initState() {
    super.initState();
    _selectedStage = widget.initialQuery.stage;
    _selectedOwner = widget.initialQuery.owner;
  }

  void _resetFilter() {
    setState(() {
      _selectedStage = null;
      _selectedOwner = null;
    });
  }

  void _applyFilter() {
    widget.onApplyFilter(OpportunityQuery(
      search: widget.initialQuery.search,
      stage: _selectedStage,
      owner: _selectedOwner,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.dividerColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(onPressed: _resetFilter, child: const Text('重置')),
                const Text('筛选', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                TextButton(onPressed: _applyFilter, child: const Text('确定')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilterSection('商机阶段', opportunityStageOptions, _selectedStage, (v) => setState(() => _selectedStage = v == '全部' ? null : v)),
                const SizedBox(height: 16),
                _buildFilterSection('负责人', opportunityOwnerOptions, _selectedOwner, (v) => setState(() => _selectedOwner = v == '全部' ? null : v)),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildFilterSection(String title, List<String> options, String? selected, void Function(String) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = (selected == null && option == '全部') || selected == option;
            return ChoiceChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (_) => onSelect(option),
              selectedColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
