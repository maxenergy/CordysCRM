import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/enterprise.dart';
import '../enterprise_provider.dart';

/// 企业信息预览弹窗
///
/// 显示从爱企查提取的企业信息，支持编辑和确认导入
class EnterprisePreviewSheet extends ConsumerStatefulWidget {
  const EnterprisePreviewSheet({super.key});

  @override
  ConsumerState<EnterprisePreviewSheet> createState() =>
      _EnterprisePreviewSheetState();
}

class _EnterprisePreviewSheetState
    extends ConsumerState<EnterprisePreviewSheet> {
  final _formKey = GlobalKey<FormState>();

  // 表单控制器
  late TextEditingController _nameController;
  late TextEditingController _creditCodeController;
  late TextEditingController _legalPersonController;
  late TextEditingController _registeredCapitalController;
  late TextEditingController _establishDateController;
  late TextEditingController _statusController;
  late TextEditingController _addressController;
  late TextEditingController _industryController;
  late TextEditingController _businessScopeController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _websiteController;

  @override
  void initState() {
    super.initState();
    final enterprise =
        ref.read(enterpriseWebProvider).pendingEnterprise ?? const Enterprise(id: '', name: '');

    _nameController = TextEditingController(text: enterprise.name);
    _creditCodeController = TextEditingController(text: enterprise.creditCode);
    _legalPersonController = TextEditingController(text: enterprise.legalPerson);
    _registeredCapitalController =
        TextEditingController(text: enterprise.registeredCapital);
    _establishDateController =
        TextEditingController(text: enterprise.establishDate);
    _statusController = TextEditingController(text: enterprise.status);
    _addressController = TextEditingController(text: enterprise.address);
    _industryController = TextEditingController(text: enterprise.industry);
    _businessScopeController =
        TextEditingController(text: enterprise.businessScope);
    _phoneController = TextEditingController(text: enterprise.phone);
    _emailController = TextEditingController(text: enterprise.email);
    _websiteController = TextEditingController(text: enterprise.website);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _creditCodeController.dispose();
    _legalPersonController.dispose();
    _registeredCapitalController.dispose();
    _establishDateController.dispose();
    _statusController.dispose();
    _addressController.dispose();
    _industryController.dispose();
    _businessScopeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  /// 构建编辑后的企业对象
  Enterprise _buildEnterprise() {
    final original = ref.read(enterpriseWebProvider).pendingEnterprise;
    return Enterprise(
      id: original?.id ?? '',
      name: _nameController.text.trim(),
      creditCode: _creditCodeController.text.trim(),
      legalPerson: _legalPersonController.text.trim(),
      registeredCapital: _registeredCapitalController.text.trim(),
      establishDate: _establishDateController.text.trim(),
      status: _statusController.text.trim(),
      address: _addressController.text.trim(),
      industry: _industryController.text.trim(),
      businessScope: _businessScopeController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      website: _websiteController.text.trim(),
    );
  }

  /// 执行导入
  Future<void> _handleImport() async {
    if (!_formKey.currentState!.validate()) return;

    // 更新企业信息
    final enterprise = _buildEnterprise();
    ref.read(enterpriseWebProvider.notifier).updatePendingEnterprise(enterprise);

    // 执行导入
    final success = await ref.read(enterpriseWebProvider.notifier).importPending();

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('导入成功'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final result = ref.read(enterpriseWebProvider).importResult;
        if (result?.isConflict == true) {
          _showConflictDialog(result!);
        }
      }
    }
  }

  /// 显示冲突对话框
  void _showConflictDialog(EnterpriseImportResult result) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('发现重复企业'),
        content: Text(result.message ?? '该企业已存在于系统中'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await ref
                  .read(enterpriseWebProvider.notifier)
                  .importPending(forceOverwrite: true);
              if (mounted) {
                if (success) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('导入成功（已覆盖）'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  final error = ref.read(enterpriseWebProvider).error;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(error ?? '导入失败'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('强制覆盖'),
          ),
        ],
      ),
    );
  }

  /// 构建表单字段
  Widget _buildField({
    required String label,
    required TextEditingController controller,
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
        validator: required
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return '$label不能为空';
                }
                return null;
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(enterpriseWebProvider);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // 拖动指示器
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 标题栏
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '核对企业信息',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        ref.read(enterpriseWebProvider.notifier).cancelImport();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),

              const Divider(),

              // 表单内容
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 基本信息
                      _buildSectionTitle('基本信息'),
                      _buildField(
                        label: '企业名称',
                        controller: _nameController,
                        required: true,
                      ),
                      _buildField(
                        label: '统一社会信用代码',
                        controller: _creditCodeController,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildField(
                              label: '法定代表人',
                              controller: _legalPersonController,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildField(
                              label: '注册资本',
                              controller: _registeredCapitalController,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildField(
                              label: '成立日期',
                              controller: _establishDateController,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildField(
                              label: '经营状态',
                              controller: _statusController,
                            ),
                          ),
                        ],
                      ),
                      _buildField(
                        label: '所属行业',
                        controller: _industryController,
                      ),

                      // 联系信息
                      _buildSectionTitle('联系信息'),
                      _buildField(
                        label: '注册地址',
                        controller: _addressController,
                        maxLines: 2,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildField(
                              label: '联系电话',
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildField(
                              label: '电子邮箱',
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ),
                        ],
                      ),
                      _buildField(
                        label: '官网',
                        controller: _websiteController,
                        keyboardType: TextInputType.url,
                      ),

                      // 经营范围
                      _buildSectionTitle('经营范围'),
                      _buildField(
                        label: '经营范围',
                        controller: _businessScopeController,
                        maxLines: 4,
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // 底部按钮
              Container(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  12 + MediaQuery.of(context).padding.bottom,
                ),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: state.isImporting ? null : _handleImport,
                    child: state.isImporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('确认导入'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 构建分组标题
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).primaryColor,
            ),
      ),
    );
  }
}
