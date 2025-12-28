import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/customer.dart';
import '../../../services/sync/sync_provider.dart';
import '../../theme/app_theme.dart';
import 'customer_provider.dart';

/// 客户编辑/新建页面
class CustomerEditPage extends ConsumerStatefulWidget {
  const CustomerEditPage({
    super.key,
    this.customerId,
  });

  final String? customerId;

  bool get isEditing => customerId != null;

  @override
  ConsumerState<CustomerEditPage> createState() => _CustomerEditPageState();
}

class _CustomerEditPageState extends ConsumerState<CustomerEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _industryController = TextEditingController();
  final _sourceController = TextEditingController();

  bool _isLoading = false;
  bool _isInitialized = false;
  Customer? _initialCustomer;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadCustomerData();
    } else {
      _isInitialized = true;
    }
  }

  Future<void> _loadCustomerData() async {
    final customer = await ref
        .read(customerDetailProvider(widget.customerId!).future);
    if (customer != null && mounted) {
      setState(() {
        _initialCustomer = customer;
        _nameController.text = customer.name;
        _contactController.text = customer.contactPerson ?? '';
        _phoneController.text = customer.phone ?? '';
        _emailController.text = customer.email ?? '';
        _addressController.text = customer.address ?? '';
        _industryController.text = customer.industry ?? '';
        _sourceController.text = customer.source ?? '';
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _industryController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    // Requirement 6.5: Check API Client availability
    final clientMonitor = ref.read(apiClientMonitorProvider);
    if (!clientMonitor.isClientAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先配置服务器地址（API 客户端不可用）'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final customerData = Customer(
      id: _initialCustomer?.id ?? '',
      name: _nameController.text.trim(),
      contactPerson: _contactController.text.trim().isEmpty
          ? null
          : _contactController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      industry: _industryController.text.trim().isEmpty
          ? null
          : _industryController.text.trim(),
      source: _sourceController.text.trim().isEmpty
          ? null
          : _sourceController.text.trim(),
      status: _initialCustomer?.status ?? '潜在客户',
      owner: _initialCustomer?.owner,
      createdAt: _initialCustomer?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await ref.read(customerFormProvider.notifier).saveCustomer(
          customerData,
          isNew: !widget.isEditing,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      // 刷新列表和详情
      ref.invalidate(customerPagingControllerProvider);
      if (widget.isEditing) {
        ref.invalidate(customerDetailProvider(widget.customerId!));
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEditing ? '客户信息已更新' : '客户创建成功'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('保存失败，请稍后重试'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 编辑模式下，等待数据加载完成
    if (widget.isEditing && !_isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('编辑客户')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? '编辑客户' : '新建客户'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveForm,
              child: const Text(
                '保存',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
              // 基本信息
              _buildSectionTitle('基本信息'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _nameController,
                label: '客户名称',
                isRequired: true,
                hintText: '请输入客户名称',
              ),
              _buildTextField(
                controller: _contactController,
                label: '联系人',
                hintText: '请输入联系人姓名',
              ),
              _buildTextField(
                controller: _phoneController,
                label: '联系电话',
                hintText: '请输入手机号码',
                keyboardType: TextInputType.phone,
                validator: _validatePhone,
              ),
              _buildTextField(
                controller: _emailController,
                label: '电子邮箱',
                hintText: '请输入邮箱地址',
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
              ),

              const SizedBox(height: 24),

              // 其他信息
              _buildSectionTitle('其他信息'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _addressController,
                label: '地址',
                hintText: '请输入详细地址',
                maxLines: 2,
              ),
              _buildTextField(
                controller: _industryController,
                label: '行业',
                hintText: '请输入所属行业',
              ),
              _buildTextField(
                controller: _sourceController,
                label: '客户来源',
                hintText: '如：线上推广、客户转介绍等',
              ),
              // 底部留白，避免被导航栏遮挡
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  /// 检查是否有未保存的更改
  bool _hasUnsavedChanges() {
    if (!widget.isEditing) {
      // 新建模式：检查是否有任何输入
      return _nameController.text.isNotEmpty ||
          _contactController.text.isNotEmpty ||
          _phoneController.text.isNotEmpty ||
          _emailController.text.isNotEmpty ||
          _addressController.text.isNotEmpty ||
          _industryController.text.isNotEmpty ||
          _sourceController.text.isNotEmpty;
    } else {
      // 编辑模式：检查是否有修改
      if (_initialCustomer == null) return false;
      return _nameController.text != _initialCustomer!.name ||
          _contactController.text != (_initialCustomer!.contactPerson ?? '') ||
          _phoneController.text != (_initialCustomer!.phone ?? '') ||
          _emailController.text != (_initialCustomer!.email ?? '') ||
          _addressController.text != (_initialCustomer!.address ?? '') ||
          _industryController.text != (_initialCustomer!.industry ?? '') ||
          _sourceController.text != (_initialCustomer!.source ?? '');
    }
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    bool isRequired = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (isRequired)
                const Text(
                  ' *',
                  style: TextStyle(color: AppTheme.errorColor),
                ),
            ],
          ),
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.errorColor),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            validator: (value) {
              if (isRequired && (value == null || value.trim().isEmpty)) {
                return '请输入$label';
              }
              if (validator != null) {
                return validator(value);
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  /// 手机号验证
  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return null;
    // 中国大陆手机号格式
    final phoneRegExp = RegExp(r'^1[3-9]\d{9}$');
    if (!phoneRegExp.hasMatch(value)) {
      return '请输入有效的手机号码';
    }
    return null;
  }

  /// 邮箱验证
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return null;
    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegExp.hasMatch(value)) {
      return '请输入有效的邮箱地址';
    }
    return null;
  }
}
