import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/enterprise_url_utils.dart';
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
  EnterpriseDataSourceType? _clipboardDataSourceType;

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

      // 使用统一的 URL 检测工具检测企查查和爱企查链接
      final detectedType = detectDataSourceFromUrl(text);
      if (detectedType != EnterpriseDataSourceType.unknown) {
        setState(() {
          _clipboardContent = text;
          _clipboardDataSourceType = detectedType;
          _showClipboardHint = true;
        });
        return;
      }

      // 检测企业名称（2-50字符，包含"公司"/"集团"/"有限"等关键词）
      if (_isCompanyName(text)) {
        setState(() {
          _clipboardContent = text;
          _clipboardDataSourceType = null;
          _showClipboardHint = true;
        });
      }
    } catch (e) {
      // 忽略剪贴板访问错误
    }
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

    final dataSourceType = _clipboardDataSourceType;

    setState(() {
      _showClipboardHint = false;
      _clipboardContent = null;
      _clipboardDataSourceType = null;
    });

    if (dataSourceType != null) {
      // 检测到企业信息链接，跳转到对应数据源的 WebView 页面
      context.push(
        AppRoutes.enterprise,
        extra: EnterpriseRouteParams(
          initialUrl: content,
          dataSourceType: dataSourceType,
        ),
      );
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

    // 监听重新搜索错误，显示 SnackBar
    ref.listen<EnterpriseSearchState>(enterpriseSearchProvider, (
      previous,
      next,
    ) {
      // 当 reSearchError 从 null 变为非 null 时显示错误提示
      if (previous?.reSearchError == null && next.reSearchError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.reSearchError!),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: '关闭',
              textColor: theme.colorScheme.onError,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('企业搜索'),
        actions: [
          // 跳转到当前数据源的 WebView 页面
          Consumer(
            builder: (context, ref, _) {
              final dataSource = ref.watch(enterpriseDataSourceProvider);
              return IconButton(
                icon: const Icon(Icons.open_in_browser),
                onPressed: () => context.push(AppRoutes.enterprise),
                tooltip: '打开${dataSource.displayName}',
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 剪贴板提示
          if (_showClipboardHint) _buildClipboardHint(),

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
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
              ),
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) => _performSearch(value.trim()),
            ),
          ),

          // 搜索结果
          Expanded(child: _buildSearchResults()),
        ],
      ),
    );
  }

  /// 构建剪贴板提示
  Widget _buildClipboardHint() {
    final isLink = _clipboardDataSourceType != null;
    final hintText = switch (_clipboardDataSourceType) {
      EnterpriseDataSourceType.qcc => '检测到企查查链接',
      EnterpriseDataSourceType.iqicha => '检测到爱企查链接',
      _ => '检测到企业名称',
    };

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
                  hintText,
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
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
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
      return const Center(child: CircularProgressIndicator());
    }

    // 优先处理需要用户操作的特定错误
    if (searchState.hasError) {
      final error = searchState.error!;
      final dataSource = ref.read(enterpriseDataSourceProvider);
      final dataSourceName = dataSource.displayName;

      // 检查是否为 WebView 页面已关闭的错误
      if (error.contains('已关闭') ||
          error.contains('请先打开') ||
          error.contains('未就绪')) {
        return _buildActionableError(
          message: error,
          buttonText: '打开$dataSourceName',
          icon: Icons.open_in_browser,
          onPressed: () async {
            // 打开 WebView 页面
            await context.push(AppRoutes.enterprise);

            // 用户返回后，如果页面仍然可用且搜索框有内容，自动重新搜索
            if (mounted && _searchController.text.trim().length >= 2) {
              _performSearch(_searchController.text.trim());
            }
          },
        );
      }

      // 检查是否为 Cookie 或验证码相关的可操作错误
      if (error.contains('登录') || error.contains('验证')) {
        return _buildActionableError(
          message: error,
          buttonText: '去登录/验证',
          icon: Icons.login,
          onPressed: () async {
            // 异步等待 WebView 页面关闭
            await context.push(AppRoutes.enterprise);

            // 用户返回后，如果页面仍然可用且搜索框有内容，自动重新搜索
            if (mounted && _searchController.text.trim().length >= 2) {
              _performSearch(_searchController.text.trim());
            }
          },
        );
      }

      // 其他一般性错误
      return _buildActionableError(
        message: error,
        buttonText: '重试',
        icon: Icons.refresh,
        onPressed: () => _performSearch(_searchController.text.trim()),
      );
    }

    // 处理无结果的情况
    if (!searchState.hasResults) {
      // 搜索过但无结果
      if (_searchController.text.trim().length >= 2) {
        return _buildEmptyState(
          icon: Icons.search_off,
          title: '未找到相关企业',
          subtitle: '数据源: ${searchState.dataSourceLabel ?? '未知'}',
        );
      }
      // 初始欢迎页
      final dataSourceType = ref.read(enterpriseDataSourceTypeProvider);
      final dataSourceName = dataSourceType == EnterpriseDataSourceType.qcc
          ? '企查查'
          : '爱企查';
      return _buildEmptyState(
        icon: Icons.business_center_outlined,
        title: '输入企业名称或信用代码',
        subtitle: '支持从本地库及$dataSourceName搜索',
      );
    }

    // 显示搜索结果列表
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

  /// 构建可操作的错误提示组件
  Widget _buildActionableError({
    required String message,
    required String buttonText,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 15),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: Icon(icon),
              label: Text(buttonText),
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建空状态/初始状态提示组件
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  /// 构建数据来源横幅
  Widget _buildDataSourceBanner(EnterpriseSearchState state) {
    final theme = Theme.of(context);
    final label = state.dataSourceLabel ?? '';
    final (icon, color) = switch (state.dataSource) {
      EnterpriseSearchDataSource.local => (Icons.storage_outlined, Colors.blue),
      EnterpriseSearchDataSource.iqicha => (Icons.public, Colors.purple),
      EnterpriseSearchDataSource.qcc => (Icons.search, Colors.green),
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
          // 重新搜索按钮（仅在本地结果时显示）
          if (state.canReSearch || state.isReSearching)
            _buildReSearchButton(state),
        ],
      ),
    );
  }

  /// 构建重新搜索按钮
  Widget _buildReSearchButton(EnterpriseSearchState state) {
    final dataSource = ref.read(enterpriseDataSourceProvider);
    final dataSourceName = dataSource.displayName;
    final isLoading = state.isReSearching;

    return TextButton.icon(
      onPressed: isLoading
          ? null
          : () {
              ref.read(enterpriseSearchProvider.notifier).reSearchExternal();
            },
      icon: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh, size: 16),
      label: Text(isLoading ? '搜索中...' : '搜索$dataSourceName'),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12),
      ),
    );
  }
}
