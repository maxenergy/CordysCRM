import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/clue.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import 'clue_provider.dart';

/// 线索编辑/新建页面
class ClueEditPage extends ConsumerStatefulWidget {
  const ClueEditPage({super.key, this.clueId});

  final String? clueId;
  bool get isEditing => clueId != null;

  @override
  ConsumerState<ClueEditPage> createState() => _ClueEditPageState();
}

class _ClueEditPageState extends ConsumerState<ClueEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _sourceController = TextEditingController();
  final _remarkController = TextEditingController();

  String _selectedStatus = Clue.statusNew;
  bool _isLoading = false;
  bool _isInitialized = false;
  Clue? _initialClue;

  static const _sourceOptions = ['线上推广', '客户转介绍', '展会活动', '电话营销', '其他'];

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadClueData();
    } else {
      _isInitialized = true;
    }
  }

  Future<void> _loadClueData() async {
    final clue = await ref.read(clueDetailProvider(widget.clueId!).future);
    if (clue != null && mounted) {
      setState(() {
        _initialClue = clue;
        _nameController.text = clue.name;
        _phoneController.text = clue.phone ?? '';
        _emailController.text = clue.email ?? '';
        _sourceController.text = clue.source ?? '';
        _remarkController.text = clue.remark ?? '';
        _selectedStatus = clue.status;
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _sourceController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final clueData = Clue(
      id: _initialClue?.id ?? '',
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      source: _sourceController.text.trim().isEmpty ? null : _sourceController.text.trim(),
      status: _selectedStatus,
      owner: _initialClue?.owner,
      remark: _remarkController.text.trim().isEmpty ? null : _remarkController.text.trim(),
      createdAt: _initialClue?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await ref.read(clueFormProvider.notifier).saveClue(
      clueData,
      isNew: !widget.isEditing,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      ref.invalidate(cluePagingControllerProvider);
      if (widget.isEditing) {
        ref.invalidate(clueDetailProvider(widget.clueId!));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEditing ? '线索信息已更新' : '线索创建成功'),
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

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing && !_isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('编辑线索')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? '编辑线索' : '新建线索'),
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
              _buildTextField(controller: _nameController, label: '线索名称', isRequired: true, hintText: '请输入线索名称'),
              _buildTextField(controller: _phoneController, label: '联系电话', hintText: '请输入手机号码', keyboardType: TextInputType.phone, validator: _validatePhone),
              _buildTextField(controller: _emailController, label: '电子邮箱', hintText: '请输入邮箱地址', keyboardType: TextInputType.emailAddress, validator: _validateEmail),
              _buildDropdownField(label: '线索来源', value: _sourceController.text.isEmpty ? null : _sourceController.text, options: _sourceOptions, onChanged: (v) => setState(() => _sourceController.text = v ?? '')),
              const SizedBox(height: 24),
              _buildSectionTitle('状态信息'),
              const SizedBox(height: 12),
              _buildStatusSelector(),
              const SizedBox(height: 24),
              _buildSectionTitle('备注'),
              const SizedBox(height: 12),
              _buildTextField(controller: _remarkController, label: '备注信息', hintText: '请输入备注信息', maxLines: 3),
              // 底部留白，避免被导航栏遮挡
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentModule: ModuleIndex.clue,
        confirmBeforeNavigate: _hasUnsavedChanges(),
        confirmMessage: '当前有未保存的线索信息，确定要离开吗？',
      ),
    );
  }

  /// 检查是否有未保存的更改
  bool _hasUnsavedChanges() {
    if (!widget.isEditing) {
      return _nameController.text.isNotEmpty ||
          _phoneController.text.isNotEmpty ||
          _emailController.text.isNotEmpty ||
          _sourceController.text.isNotEmpty ||
          _remarkController.text.isNotEmpty;
    } else {
      if (_initialClue == null) return false;
      return _nameController.text != _initialClue!.name ||
          _phoneController.text != (_initialClue!.phone ?? '') ||
          _emailController.text != (_initialClue!.email ?? '') ||
          _sourceController.text != (_initialClue!.source ?? '') ||
          _remarkController.text != (_initialClue!.remark ?? '') ||
          _selectedStatus != _initialClue!.status;
    }
  }

  Widget _buildSectionTitle(String title) => Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary));

  Widget _buildTextField({required TextEditingController controller, required String label, String? hintText, bool isRequired = false, TextInputType? keyboardType, int maxLines = 1, String? Function(String?)? validator}) {
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
              return validator?.call(value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({required String label, String? value, required List<String> options, required ValueChanged<String?> onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: options.contains(value) ? value : null,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.borderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.borderColor)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            hint: const Text('请选择', style: TextStyle(color: AppTheme.textTertiary)),
            items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSelector() {
    final statuses = [
      (Clue.statusNew, '新线索', AppTheme.primaryColor),
      (Clue.statusFollowing, '跟进中', AppTheme.warningColor),
      (Clue.statusConverted, '已转化', AppTheme.successColor),
      (Clue.statusInvalid, '无效', AppTheme.textTertiary),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: statuses.map((s) {
        final isSelected = _selectedStatus == s.$1;
        return ChoiceChip(
          label: Text(s.$2),
          selected: isSelected,
          selectedColor: s.$3.withValues(alpha: 0.2),
          labelStyle: TextStyle(color: isSelected ? s.$3 : AppTheme.textSecondary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
          onSelected: (_) => setState(() => _selectedStatus = s.$1),
        );
      }).toList(),
    );
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return null;
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(value)) return '请输入有效的手机号码';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return null;
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return '请输入有效的邮箱地址';
    return null;
  }
}
