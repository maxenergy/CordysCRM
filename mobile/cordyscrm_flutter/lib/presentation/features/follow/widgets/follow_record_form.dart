import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/follow_record.dart';
import '../../../theme/app_theme.dart';
import '../follow_provider.dart';

/// 跟进记录表单组件
class FollowRecordForm extends ConsumerStatefulWidget {
  const FollowRecordForm({
    super.key,
    this.customerId,
    this.clueId,
    required this.onSuccess,
  });

  final String? customerId;
  final String? clueId;
  final VoidCallback onSuccess;

  @override
  ConsumerState<FollowRecordForm> createState() => _FollowRecordFormState();
}

class _FollowRecordFormState extends ConsumerState<FollowRecordForm> {
  final _contentController = TextEditingController();
  String _selectedType = FollowRecord.typePhone;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入跟进内容'), backgroundColor: AppTheme.errorColor),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final record = FollowRecord(
      id: '',
      customerId: widget.customerId,
      clueId: widget.clueId,
      content: _contentController.text.trim(),
      followType: _selectedType,
      followAt: DateTime.now(),
    );

    final success = await ref.read(followFormProvider.notifier).createFollowRecord(record);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      _contentController.clear();
      widget.onSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('跟进记录已保存'), backgroundColor: AppTheme.successColor),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存失败，请重试'), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('新建跟进', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 跟进类型选择
          const Text('跟进方式', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: followTypeOptions.map((option) {
              final (type, label, _) = option;
              final isSelected = _selectedType == type;
              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedType = type),
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
          const SizedBox(height: 16),
          // 跟进内容
          const Text('跟进内容', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          TextField(
            controller: _contentController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: '请输入跟进内容...',
              hintStyle: const TextStyle(color: AppTheme.textTertiary),
              filled: true,
              fillColor: AppTheme.backgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 16),
          // 附件按钮（占位）
          Row(
            children: [
              _AttachmentButton(icon: Icons.image_outlined, label: '图片', onTap: () => _showComingSoon('图片上传')),
              const SizedBox(width: 12),
              _AttachmentButton(icon: Icons.mic_outlined, label: '语音', onTap: () => _showComingSoon('语音录制')),
            ],
          ),
          const SizedBox(height: 24),
          // 提交按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('保存跟进', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature功能开发中')),
    );
  }
}

class _AttachmentButton extends StatelessWidget {
  const _AttachmentButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}
