import 'package:flutter/material.dart';

import '../../../../domain/entities/customer.dart';
import '../../../theme/app_theme.dart';
import '../customer_provider.dart';

/// 客户筛选底部弹窗
class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({
    super.key,
    required this.initialQuery,
    required this.onApplyFilter,
  });

  final CustomerQuery initialQuery;
  final ValueChanged<CustomerQuery> onApplyFilter;

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late String _selectedStatus;
  late String _selectedOwner;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialQuery.status ?? '全部';
    _selectedOwner = widget.initialQuery.owner ?? '全部';
    if (widget.initialQuery.startDate != null ||
        widget.initialQuery.endDate != null) {
      _selectedDateRange = DateTimeRange(
        start: widget.initialQuery.startDate ??
            DateTime.now().subtract(const Duration(days: 365)),
        end: widget.initialQuery.endDate ?? DateTime.now(),
      );
    }
  }

  void _apply() {
    widget.onApplyFilter(
      CustomerQuery(
        search: widget.initialQuery.search,
        status: _selectedStatus == '全部' ? null : _selectedStatus,
        owner: _selectedOwner == '全部' ? null : _selectedOwner,
        startDate: _selectedDateRange?.start,
        endDate: _selectedDateRange?.end,
      ),
    );
    Navigator.pop(context);
  }

  void _reset() {
    setState(() {
      _selectedStatus = '全部';
      _selectedOwner = '全部';
      _selectedDateRange = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '筛选',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 客户状态
            _buildDropdown(
              label: '客户状态',
              value: _selectedStatus,
              items: customerStatusOptions,
              onChanged: (val) => setState(() => _selectedStatus = val!),
            ),
            const SizedBox(height: 16),

            // 负责人
            _buildDropdown(
              label: '负责人',
              value: _selectedOwner,
              items: customerOwnerOptions,
              onChanged: (val) => setState(() => _selectedOwner = val!),
            ),
            const SizedBox(height: 16),

            // 创建时间
            _buildDateRangePicker(),
            const SizedBox(height: 24),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reset,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: const Text('重置'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: const Text('确定'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDateRangePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '创建时间',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _selectDateRange,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.borderColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.date_range, size: 20, color: AppTheme.textTertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedDateRange == null
                        ? '选择日期范围'
                        : '${_formatDate(_selectedDateRange!.start)} - ${_formatDate(_selectedDateRange!.end)}',
                    style: TextStyle(
                      color: _selectedDateRange == null
                          ? AppTheme.textTertiary
                          : AppTheme.textPrimary,
                    ),
                  ),
                ),
                if (_selectedDateRange != null)
                  GestureDetector(
                    onTap: () => setState(() => _selectedDateRange = null),
                    child: const Icon(
                      Icons.clear,
                      size: 20,
                      color: AppTheme.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange,
      locale: const Locale('zh', 'CN'),
    );
    if (range != null) {
      setState(() => _selectedDateRange = range);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
