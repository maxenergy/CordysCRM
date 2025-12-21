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

    // 如果企业需要获取详情，自动开始加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDetailIfNeeded();
    });
  }

  /// 如果需要，获取企业详情
  Future<void> _fetchDetailIfNeeded() async {
    final enterprise = ref.read(enterpriseWebProvider).pendingEnterprise;
    if (enterprise != null && enterprise.needsDetailFetch) {
      debugPrint('[预览弹窗] 企业需要获取详情，开始加载...');
      await ref.read(enterpriseWebProvider.notifier).fetchEnterpriseDetail();
    }
  }

  /// 当详情加载完成后，更新表单控制器
  void _updateControllersFromEnterprise(Enterprise enterprise) {
    _nameController.text = enterprise.name;
    _creditCodeController.text = enterprise.creditCode;
    _legalPersonController.text = enterprise.legalPerson;
    _registeredCapitalController.text = enterprise.registeredCapital;
    _establishDateController.text = enterprise.establishDate;
    _statusController.text = enterprise.status;
    _addressController.text = enterprise.address;
    _industryController.text = enterprise.industry;
    _businessScopeController.text = enterprise.businessScope;
    _phoneController.text = enterprise.phone;
    _emailController.text = enterprise.email;
    _websiteController.text = enterprise.website;
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
    debugPrint('[导入] 开始导入流程');
    
    if (!_formKey.currentState!.validate()) {
      debugPrint('[导入] 表单验证失败');
      return;
    }

    // 更新企业信息
    final enterprise = _buildEnterprise();
    debugPrint('[导入] 构建企业对象: name=${enterprise.name}, creditCode=${enterprise.creditCode}, source=${enterprise.source}');
    ref.read(enterpriseWebProvider.notifier).updatePendingEnterprise(enterprise);

    // 执行导入
    debugPrint('[导入] 调用 importPending()...');
    final success = await ref.read(enterpriseWebProvider.notifier).importPending();
    debugPrint('[导入] importPending() 返回: success=$success');

    if (mounted) {
      if (success) {
        debugPrint('[导入] 导入成功，关闭弹窗');
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('导入成功'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final result = ref.read(enterpriseWebProvider).importResult;
        final error = ref.read(enterpriseWebProvider).error;
        debugPrint('[导入] 导入失败: result=${result?.status}, error=$error');
        
        if (result?.isConflict == true) {
          _showConflictDialog(result!);
        } else if (error != null) {
          // 显示错误信息
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('导入失败: $error'),
              backgroundColor: Colors.red,
            ),
          );
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
    bool isLoading = false,
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
          suffixIcon: isLoading && controller.text.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
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

    // 监听详情加载完成，更新表单
    ref.listen<EnterpriseWebState>(enterpriseWebProvider, (previous, next) {
      if (previous?.detailFetchStatus == DetailFetchStatus.loading &&
          next.detailFetchStatus == DetailFetchStatus.success &&
          next.pendingEnterprise != null) {
        debugPrint('[预览弹窗] 详情加载完成，更新表单');
        _updateControllersFromEnterprise(next.pendingEnterprise!);
      }
    });

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

              // 详情加载状态提示
              if (state.isLoadingDetail)
                _buildDetailLoadingBanner(theme),
              if (state.detailFetchFailed && state.detailFetchError != null)
                _buildDetailErrorBanner(theme, state.detailFetchError!),

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
                        isLoading: state.isLoadingDetail,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildField(
                              label: '联系电话',
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              isLoading: state.isLoadingDetail,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildField(
                              label: '电子邮箱',
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              isLoading: state.isLoadingDetail,
                            ),
                          ),
                        ],
                      ),
                      _buildField(
                        label: '官网',
                        controller: _websiteController,
                        keyboardType: TextInputType.url,
                        isLoading: state.isLoadingDetail,
                      ),

                      // 经营范围
                      _buildSectionTitle('经营范围'),
                      _buildField(
                        label: '经营范围',
                        controller: _businessScopeController,
                        maxLines: 4,
                        isLoading: state.isLoadingDetail,
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

  /// 构建详情加载中提示
  Widget _buildDetailLoadingBanner(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '正在获取企业详细信息...',
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建详情加载失败提示
  Widget _buildDetailErrorBanner(ThemeData theme, String error) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '详情获取失败，可直接导入基础信息',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade900,
              ),
            ),
          ),
          TextButton(
            onPressed: _fetchDetailIfNeeded,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
            ),
            child: const Text('重试'),
          ),
        ],
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
