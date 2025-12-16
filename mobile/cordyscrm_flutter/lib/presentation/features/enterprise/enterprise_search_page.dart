import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/enterprise.dart';
import '../../routing/app_router.dart';
import 'enterprise_provider.dart';
import 'widgets/enterprise_search_result_item.dart';

/// 企业搜索页面
///
/// 支持手动搜索企业、剪贴板识别、分享链接解析
class EnterpriseSearchPage extends ConsumerStatefulWidget {
  const EnterpriseSearchPage({super.key});

  @override
  ConsumerState<EnterpriseSearchPage> createState() =>
      _EnterpriseSearchPageState();
}

class _EnterpriseSearchPageState extends ConsumerState<EnterpriseSearchPage>
    with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounceTimer;

  // 剪贴板检测
  String? _clipboardContent;
  bool _showClipboardHint = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkClipboard();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 应用进入前台时检测剪贴板
    if (state == AppLifecycleState.resumed) {
      _checkClipboard();
    }
  }

  /// 检测剪贴板内容
  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';

      if (text.isEmpty) return;

      // 检测爱企查链接
      if (_isAiqichaLink(text)) {
        setState(() {
          _clipboardContent = text;
          _showClipboardHint = true;
        });
        return;
      }

      // 检测企业名称（2-50字符，包含"公司"/"集团"/"有限"等关键词）
      if (_isCompanyName(text)) {
        setState(() {
          _clipboardContent = text;
          _showClipboardHint = true;
        });
      }
    } catch (e) {
      // 忽略剪贴板访问错误
    }
  }

  /// 检测是否为爱企查链接
  bool _isAiqichaLink(String text) {
    return text.contains('aiqicha.baidu.com') &&
        (text.contains('company_detail') || text.contains('pid='));
  }

  /// 检测是否为企业名称
  bool _isCompanyName(String text) {
    if (text.length < 2 || text.length > 50) return false;

    // 包含企业关键词
    final keywords = ['公司', '集团', '有限', '股份', '企业', '工厂', '厂'];
    return keywords.any((k) => text.contains(k));
  }

  /// 处理剪贴板内容
  void _handleClipboardContent() {
    final content = _clipboardContent;
    if (content == null) return;

    setState(() {
      _showClipboardHint = false;
      _clipboardContent = null; // 清除已处理的剪贴板内容
    });

    if (_isAiqichaLink(content)) {
      // 跳转到 WebView 页面
      context.push(AppRoutes.enterprise);
    } else {
      // 填充搜索框并搜索
      _searchController.text = content;
      _performSearch(content);
    }
  }

  /// 执行搜索（带防抖）
  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();

    if (value.trim().length < 2) {
      ref.read(enterpriseSearchProvider.notifier).clear();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(value.trim());
    });
  }

  /// 执行搜索
  Future<void> _performSearch(String keyword) async {
    if (keyword.length < 2) return;
    await ref.read(enterpriseSearchProvider.notifier).search(keyword);
  }

  /// 选择企业
  void _onEnterpriseSelected(Enterprise enterprise) {
    ref.read(enterpriseWebProvider.notifier).setPendingEnterprise(enterprise);
    // 跳转到 WebView 页面查看详情
    context.push(AppRoutes.enterprise);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('企业搜索'),
        actions: [
          // 跳转到 WebView 页面
          IconButton(
            icon: const Icon(Icons.public),
            onPressed: () => context.push(AppRoutes.enterprise),
            tooltip: '打开爱企查',
          ),
        ],
      ),
      body: Column(
        children: [
          // 剪贴板提示
          if (_showClipboardHint)
            _buildClipboardHint(),

          // 搜索框
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: '输入企业名称或信用代码搜索',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(enterpriseSearchProvider.notifier).clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              ),
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) => _performSearch(value.trim()),
            ),
          ),

          // 搜索结果
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  /// 构建剪贴板提示
  Widget _buildClipboardHint() {
    final isLink = _isAiqichaLink(_clipboardContent ?? '');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isLink ? Icons.link : Icons.business,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLink ? '检测到爱企查链接' : '检测到企业名称',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  _clipboardContent ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimaryContainer
                        .withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _handleClipboardContent,
            child: Text(isLink ? '打开' : '搜索'),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              setState(() {
                _showClipboardHint = false;
              });
            },
          ),
        ],
      ),
    );
  }

  /// 构建搜索结果
  Widget _buildSearchResults() {
    final searchState = ref.watch(enterpriseSearchProvider);

    if (searchState.isSearching) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (searchState.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                searchState.error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _performSearch(_searchController.text.trim()),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (!searchState.hasResults) {
      if (_searchController.text.trim().length >= 2) {
        final label = searchState.dataSourceLabel;
        final hint = switch (searchState.dataSource) {
          EnterpriseSearchDataSource.local =>
            'CRM 本地库无数据',
          EnterpriseSearchDataSource.iqicha =>
            '爱企查无匹配（或 Cookie 失效，请先登录）',
          EnterpriseSearchDataSource.mixed => '未找到相关企业',
          _ => '请先通过 WebView 登录爱企查',
        };

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('未找到相关企业'),
              const SizedBox(height: 8),
              Text(
                label == null ? hint : '$label：$hint',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        );
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.business_center_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '输入企业名称或信用代码搜索',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              '或点击右上角打开爱企查网站',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    final showHeader = searchState.dataSourceLabel != null;
    final headerOffset = showHeader ? 1 : 0;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: searchState.results.length + headerOffset,
      itemBuilder: (context, index) {
        if (showHeader && index == 0) {
          return _buildDataSourceBanner(searchState);
        }
        final enterprise = searchState.results[index - headerOffset];
        return EnterpriseSearchResultItem(
          enterprise: enterprise,
          onTap: () => _onEnterpriseSelected(enterprise),
        );
      },
    );
  }

  /// 构建数据来源横幅
  Widget _buildDataSourceBanner(EnterpriseSearchState state) {
    final theme = Theme.of(context);
    final label = state.dataSourceLabel ?? '';
    final (icon, color) = switch (state.dataSource) {
      EnterpriseSearchDataSource.local => (Icons.storage_outlined, Colors.blue),
      EnterpriseSearchDataSource.iqicha => (Icons.public, Colors.purple),
      EnterpriseSearchDataSource.mixed => (Icons.layers_outlined, Colors.teal),
      _ => (Icons.info_outline, theme.colorScheme.primary),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '结果来源：$label',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
