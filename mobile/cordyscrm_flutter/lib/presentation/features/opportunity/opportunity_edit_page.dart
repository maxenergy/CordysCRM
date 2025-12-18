import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/opportunity.dart';
import '../../theme/app_theme.dart';
import 'opportunity_provider.dart';

/// 商机编辑/新建页面
class OpportunityEditPage extends ConsumerStatefulWidget {
  const OpportunityEditPage({super.key, this.opportunityId});

  final String? opportunityId;
  bool get isEditing => opportunityId != null;

  @override
  ConsumerState<OpportunityEditPage> createState() => _OpportunityEditPageState();
}

class _OpportunityEditPageState extends ConsumerState<OpportunityEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _probabilityController = TextEditingController();
  final _remarkController = TextEditingController();

  String _selectedStage = Opportunity.stageInitial;
  DateTime? _expectedCloseDate;
  bool _isLoading = false;
  bool _isInitialized = false;
  Opportunity? _initialOpportunity;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadOpportunityData();
    } else {
      _isInitialized = true;
      _probabilityController.text = '30';
    }
  }

  Future<void> _loadOpportunityData() async {
    final opportunity = await ref.read(opportunityDetailProvider(widget.opportunityId!).future);
    if (opportunity != null && mounted) {
      setState(() {
        _initialOpportunity = opportunity;
        _nameController.text = opportunity.name;
        _customerNameController.text = opportunity.customerName ?? '';
        _amountController.text = opportunity.amount?.toStringAsFixed(2) ?? '';
        _probabilityController.text = opportunity.probability?.toString() ?? '30';
        _remarkController.text = opportunity.remark ?? '';
        _selectedStage = opportunity.stage;
        _expectedCloseDate = opportunity.expectedCloseDate;
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customerNameController.dispose();
    _amountController.dispose();
    _probabilityController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final opportunityData = Opportunity(
      id: _initialOpportunity?.id ?? '',
      name: _nameController.text.trim(),
      customerId: _initialOpportunity?.customerId,
      customerName: _customerNameController.text.trim().isEmpty ? null : _customerNameController.text.trim(),
      amount: double.tryParse(_amountController.text.trim()),
      stage: _selectedStage,
      probability: int.tryParse(_probabilityController.text.trim()),
      expectedCloseDate: _expectedCloseDate,
      owner: _initialOpportunity?.owner,
      remark: _remarkController.text.trim().isEmpty ? null : _remarkController.text.trim(),
      createdAt: _initialOpportunity?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await ref.read(opportunityFormProvider.notifier).saveOpportunity(
      opportunityData,
      isNew: !widget.isEditing,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      ref.invalidate(opportunityPagingControllerProvider);
      if (widget.isEditing) {
        ref.invalidate(opportunityDetailProvider(widget.opportunityId!));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEditing ? '商机信息已更新' : '商机创建成功'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存失败，请稍后重试'), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expectedCloseDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _expectedCloseDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing && !_isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('编辑商机')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? '编辑商机' : '新建商机'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            TextButton(
              onPressed: _saveForm,
              child: const Text('保存', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('基本信息'),
              const SizedBox(height: 12),
              _buildTextField(controller: _nameController, label: '商机名称', isRequired: true, hintText: '请输入商机名称'),
              _buildTextField(controller: _customerNameController, label: '关联客户', hintText: '请输入客户名称'),
              _buildTextField(controller: _amountController, label: '预计金额（元）', hintText: '请输入预计金额', keyboardType: TextInputType.number),
              _buildDateField(),
              const SizedBox(height: 24),
              _buildSectionTitle('商机阶段'),
              const SizedBox(height: 12),
              _buildStageSelector(),
              const SizedBox(height: 24),
              _buildSectionTitle('成交概率'),
              const SizedBox(height: 12),
              _buildProbabilitySlider(),
              const SizedBox(height: 24),
              _buildSectionTitle('备注'),
              const SizedBox(height: 12),
              _buildTextField(controller: _remarkController, label: '备注信息', hintText: '请输入备注信息', maxLines: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary));

  Widget _buildTextField({required TextEditingController controller, required String label, String? hintText, bool isRequired = false, TextInputType? keyboardType, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
            if (isRequired) const Text(' *', style: TextStyle(color: AppTheme.errorColor)),
          ]),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(color: AppTheme.textTertiary),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.borderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            validator: (value) {
              if (isRequired && (value == null || value.trim().isEmpty)) return '请输入$label';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('预计成交日期', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          InkWell(
            onTap: _selectDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppTheme.borderColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _expectedCloseDate != null ? DateFormat('yyyy-MM-dd').format(_expectedCloseDate!) : '请选择日期',
                      style: TextStyle(color: _expectedCloseDate != null ? AppTheme.textPrimary : AppTheme.textTertiary),
                    ),
                  ),
                  const Icon(Icons.calendar_today, size: 20, color: AppTheme.textSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageSelector() {
    final stages = [
      (Opportunity.stageInitial, '初步接触', AppTheme.primaryColor),
      (Opportunity.stageQualified, '需求确认', Colors.blue),
      (Opportunity.stageProposal, '方案报价', Colors.orange),
      (Opportunity.stageNegotiation, '商务谈判', Colors.purple),
      (Opportunity.stageWon, '赢单', AppTheme.successColor),
      (Opportunity.stageLost, '输单', AppTheme.errorColor),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: stages.map((s) {
        final isSelected = _selectedStage == s.$1;
        return ChoiceChip(
          label: Text(s.$2),
          selected: isSelected,
          selectedColor: s.$3.withValues(alpha: 0.2),
          labelStyle: TextStyle(color: isSelected ? s.$3 : AppTheme.textSecondary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
          onSelected: (_) => setState(() => _selectedStage = s.$1),
        );
      }).toList(),
    );
  }

  Widget _buildProbabilitySlider() {
    final probability = int.tryParse(_probabilityController.text) ?? 30;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('成交概率', style: TextStyle(color: AppTheme.textSecondary)),
            Text('$probability%', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
          ],
        ),
        Slider(
          value: probability.toDouble(),
          min: 0,
          max: 100,
          divisions: 20,
          activeColor: AppTheme.primaryColor,
          onChanged: (v) => setState(() => _probabilityController.text = v.round().toString()),
        ),
      ],
    );
  }
}
