import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/call_script.dart';
import '../ai_provider.dart';

/// AI 话术生成抽屉组件
///
/// 底部弹出的话术生成面板，支持场景/渠道/语气选择
class AIScriptDrawer extends ConsumerStatefulWidget {
  const AIScriptDrawer({
    super.key,
    required this.customerId,
    this.customerName,
    this.scrollController,
  });

  final String customerId;
  final String? customerName;
  final ScrollController? scrollController;

  /// 显示话术生成抽屉
  static Future<void> show(BuildContext context, String customerId, {String? customerName}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AIScriptDrawer(customerId: customerId, customerName: customerName),
    );
  }

  @override
  ConsumerState<AIScriptDrawer> createState() => _AIScriptDrawerState();
}

class _AIScriptDrawerState extends ConsumerState<AIScriptDrawer> {
  final _contentController = TextEditingController();
  bool _showHistory = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  /// 复制到剪贴板
  void _copyToClipboard() {
    final content = _contentController.text;
    if (content.isEmpty) return;

    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制到剪贴板'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// 保存为模板
  Future<void> _saveAsTemplate() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _SaveTemplateDialog(),
    );

    if (name != null && name.isNotEmpty) {
      final success = await ref
          .read(scriptProvider(widget.customerId).notifier)
          .saveAsTemplate(name);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '模板保存成功' : '保存失败'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scriptProvider(widget.customerId));
    final theme = Theme.of(context);

    // 同步内容到控制器
    if (state.generatedScript != null &&
        _contentController.text != state.generatedScript!.content) {
      _contentController.text = state.generatedScript!.content;
    }

    // 如果外部提供了 scrollController，直接使用简化布局
    if (widget.scrollController != null) {
      return _buildContent(state, theme, widget.scrollController!);
    }

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
          return _buildContent(state, theme, scrollController);
        },
      ),
    );
  }

  Widget _buildContent(ScriptState state, ThemeData theme, ScrollController scrollController) {
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
                    Icon(
                      Icons.auto_fix_high,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI 话术生成',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (widget.customerName != null)
                            Text(
                              widget.customerName!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(),

              // 内容区域
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 场景选择
                    _buildSectionTitle('选择场景'),
                    _buildSceneChips(state),
                    const SizedBox(height: 16),

                    // 渠道选择
                    _buildSectionTitle('选择渠道'),
                    _buildChannelChips(state),
                    const SizedBox(height: 16),

                    // 语气选择
                    _buildSectionTitle('选择语气'),
                    _buildToneChips(state),
                    const SizedBox(height: 24),

                    // 生成按钮
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: state.isGenerating
                            ? null
                            : () {
                                ref
                                    .read(scriptProvider(widget.customerId).notifier)
                                    .generateScript();
                              },
                        icon: state.isGenerating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.auto_awesome),
                        label: Text(state.isGenerating ? '生成中...' : '生成话术'),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 结果展示
                    _buildResultSection(state),

                    // 历史记录
                    if (state.history.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildHistorySection(state),
                    ],
                  ],
                ),
              ),
            ],
          );
  }

  /// 构建分组标题
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  /// 构建场景选择
  Widget _buildSceneChips(ScriptState state) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ScriptScene.values.map((scene) {
        final isSelected = state.scene == scene;
        return ChoiceChip(
          label: Text(scene.label),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              ref
                  .read(scriptProvider(widget.customerId).notifier)
                  .setScene(scene);
            }
          },
        );
      }).toList(),
    );
  }

  /// 构建渠道选择
  Widget _buildChannelChips(ScriptState state) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ScriptChannel.values.map((channel) {
        final isSelected = state.channel == channel;
        return ChoiceChip(
          label: Text(channel.label),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              ref
                  .read(scriptProvider(widget.customerId).notifier)
                  .setChannel(channel);
            }
          },
        );
      }).toList(),
    );
  }

  /// 构建语气选择
  Widget _buildToneChips(ScriptState state) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ScriptTone.values.map((tone) {
        final isSelected = state.tone == tone;
        return ChoiceChip(
          label: Text(tone.label),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              ref
                  .read(scriptProvider(widget.customerId).notifier)
                  .setTone(tone);
            }
          },
        );
      }).toList(),
    );
  }

  /// 构建结果展示区域
  Widget _buildResultSection(ScriptState state) {
    if (!state.hasScript) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.grey.shade300,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              Icons.edit_note,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              '点击上方按钮生成话术',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('生成结果'),
        TextField(
          controller: _contentController,
          maxLines: 8,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            hintText: '话术内容',
          ),
          onChanged: (value) {
            ref
                .read(scriptProvider(widget.customerId).notifier)
                .updateScriptContent(value);
          },
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: _copyToClipboard,
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('复制'),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _saveAsTemplate,
              icon: const Icon(Icons.save, size: 18),
              label: const Text('存为模板'),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建历史记录区域
  Widget _buildHistorySection(ScriptState state) {
    return ExpansionTile(
      title: const Text('历史记录'),
      leading: const Icon(Icons.history),
      initiallyExpanded: _showHistory,
      onExpansionChanged: (expanded) {
        setState(() {
          _showHistory = expanded;
        });
      },
      children: state.history.map((script) {
        return ListTile(
          dense: true,
          title: Text(
            script.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${script.scene.label} · ${script.channel.label} · ${script.tone.label}',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Text(
            _formatTime(script.createdAt),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          onTap: () {
            ref
                .read(scriptProvider(widget.customerId).notifier)
                .loadFromHistory(script);
          },
        );
      }).toList(),
    );
  }

  /// 格式化时间
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}小时前';
    } else {
      return '${diff.inDays}天前';
    }
  }
}

/// 保存模板对话框
class _SaveTemplateDialog extends StatefulWidget {
  @override
  State<_SaveTemplateDialog> createState() => _SaveTemplateDialogState();
}

class _SaveTemplateDialogState extends State<_SaveTemplateDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('保存为模板'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: '模板名称',
          hintText: '请输入模板名称',
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, _controller.text.trim());
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
