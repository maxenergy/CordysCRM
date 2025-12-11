import 'package:flutter/material.dart';

import '../../../../domain/repositories/clue_repository.dart';
import '../../../theme/app_theme.dart';
import '../clue_provider.dart';

/// 线索筛选弹窗
class ClueFilterSheet extends StatefulWidget {
  const ClueFilterSheet({
    super.key,
    required this.initialQuery,
    required this.onApplyFilter,
  });

  final ClueQuery initialQuery;
  final void Function(ClueQuery) onApplyFilter;

  @override
  State<ClueFilterSheet> createState() => _ClueFilterSheetState();
}

class _ClueFilterSheetState extends State<ClueFilterSheet> {
  late String? _selectedStatus;
  late String? _selectedOwner;
  late String? _selectedSource;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialQuery.status;
    _selectedOwner = widget.initialQuery.owner;
    _selectedSource = widget.initialQuery.source;
  }

  void _resetFilter() {
    setState(() {
      _selectedStatus = null;
      _selectedOwner = null;
      _selectedSource = null;
    });
  }

  void _applyFilter() {
    widget.onApplyFilter(ClueQuery(
      search: widget.initialQuery.search,
      status: _selectedStatus,
      owner: _selectedOwner,
      source: _selectedSource,
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
          // 标题栏
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
          // 筛选内容
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilterSection('线索状态', clueStatusOptions, _selectedStatus, (v) => setState(() => _selectedStatus = v == '全部' ? null : v)),
                const SizedBox(height: 16),
                _buildFilterSection('负责人', clueOwnerOptions, _selectedOwner, (v) => setState(() => _selectedOwner = v == '全部' ? null : v)),
                const SizedBox(height: 16),
                _buildFilterSection('来源', clueSourceOptions, _selectedSource, (v) => setState(() => _selectedSource = v == '全部' ? null : v)),
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
