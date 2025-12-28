import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/enterprise_url_utils.dart';
import '../../../domain/datasources/enterprise_data_source.dart';
import '../../../domain/entities/enterprise.dart';
import 'enterprise_provider.dart';
import 'widgets/enterprise_preview_sheet.dart';
import 'widgets/enterprise_search_result_item.dart';
import 'widgets/selection_bar.dart';

/// 企业搜索页面（集成 WebView）
///
/// 将 WebView 嵌入页面内部，使用 IndexedStack 切换搜索视图和 WebView 视图，
/// 避免 WebView 页面被销毁导致控制器失效。
class EnterpriseSearchWithWebViewPage extends ConsumerStatefulWidget {
  const EnterpriseSearchWithWebViewPage({super.key});

  @override
  ConsumerState<EnterpriseSearchWithWebViewPage> createState() =>
      _EnterpriseSearchWithWebViewPageState();
}

class _EnterpriseSearchWithWebViewPageState
    extends ConsumerState<EnterpriseSearchWithWebViewPage>
    with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounceTimer;

  // 视图切换：0 = 搜索视图，1 = WebView 视图
  int _currentViewIndex = 0;

  // WebView 相关
  InAppWebViewController? _webViewController;
  bool _webViewInitialized = false;
  int _webViewProgress = 0;
  bool _webViewLoading = false;

  // 剪贴板检测
  String? _clipboardContent;
  bool _showClipboardHint = false;
  EnterpriseDataSourceType? _clipboardDataSourceType;

  // 自动提取标志：从搜索结果跳转到详情页后自动提取数据
  bool _pendingAutoExtract = false;
  Timer? _autoExtractTimeoutTimer;
  
  // 抑制自动进入选择模式的标志（用于批量导入后的刷新）
  bool _suppressAutoEnterSelection = false;

  // 桌面版 User-Agent，避免被重定向到移动版 m.qcc.com
  static const _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  // WebView 配置
  final InAppWebViewSettings _webViewSettings = InAppWebViewSettings(
    useShouldOverrideUrlLoading: true,
    javaScriptEnabled: true,
    domStorageEnabled: true,
    mediaPlaybackRequiresUserGesture: false,
    allowsInlineMediaPlayback: true,
    useHybridComposition: true,
    // 强制桌面 UA，避免重定向到 https://m.qcc.com/
    userAgent: _desktopUserAgent,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkClipboard();

    // 在页面初始化后，短暂切换到 WebView 视图以确保 WebView 被创建
    // 然后立即切换回搜索视图
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWebView();
    });
  }

  /// 初始化 WebView
  ///
  /// WebView 通过 Opacity + IgnorePointer 的方式始终 attach 到界面并保持非零尺寸，
  /// 不再需要通过切换视图来"唤醒/创建"原生 WebView。
  void _initializeWebView() {
    // no-op: WebView 始终保持 attach 状态
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    _autoExtractTimeoutTimer?.cancel();

    // 清空 WebViewController 引用
    _clearWebViewControllerRef();

    super.dispose();
  }

  /// 清空 WebView 控制器引用
  void _clearWebViewControllerRef() {
    try {
      ref.read(webViewControllerProvider.notifier).state = null;
    } catch (_) {}

    // 清理未完成的企查查搜索 completers
    try {
      final qccCompleters = ref.read(qichachaSearchCompleterProvider);
      if (qccCompleters.isNotEmpty) {
        for (final completer in qccCompleters.values) {
          if (!completer.isCompleted) {
            completer.completeError('WebView disposed');
          }
        }
      }
      ref.read(qichachaSearchCompleterProvider.notifier).state =
          <int, Completer<Object>>{};
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboard();
    }
  }

  /// 获取当前数据源
  EnterpriseDataSourceInterface get _dataSource =>
      ref.read(enterpriseDataSourceProvider);

  /// 切换到搜索视图
  void _showSearchView() {
    setState(() {
      _currentViewIndex = 0;
    });
  }

  /// 切换到 WebView 视图
  void _showWebView() {
    setState(() {
      _currentViewIndex = 1;
    });
  }

  /// 检测剪贴板内容
  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';

      if (text.isEmpty) return;

      final detectedType = detectDataSourceFromUrl(text);
      if (detectedType != EnterpriseDataSourceType.unknown) {
        setState(() {
          _clipboardContent = text;
          _clipboardDataSourceType = detectedType;
          _showClipboardHint = true;
        });
        return;
      }

      if (_isCompanyName(text)) {
        setState(() {
          _clipboardContent = text;
          _clipboardDataSourceType = null;
          _showClipboardHint = true;
        });
      }
    } catch (_) {}
  }

  bool _isCompanyName(String text) {
    if (text.length < 2 || text.length > 50) return false;
    final keywords = ['公司', '集团', '有限', '股份', '企业', '工厂', '厂'];
    return keywords.any((k) => text.contains(k));
  }

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
      // 检测到链接，加载到 WebView
      _webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(content)));
      _showWebView();
    } else {
      _searchController.text = content;
      _performSearch(content);
    }
  }

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

  Future<void> _performSearch(String keyword) async {
    if (keyword.length < 2) return;
    
    // 新搜索前退出选择模式，避免旧选择污染新结果
    final searchState = ref.read(enterpriseSearchProvider);
    if (searchState.isSelectionMode) {
      ref.read(enterpriseSearchProvider.notifier).exitSelectionMode();
    }
    
    // 搜索前记录 WebView URL 状态，便于调试
    await _logQccUrlBeforeSearch(
      keyword,
    ).timeout(const Duration(milliseconds: 500), onTimeout: () {});
    await ref.read(enterpriseSearchProvider.notifier).search(keyword);
    
    // 搜索完成后，如果有可选企业，自动进入选择模式
    // 但如果设置了抑制标志（如批量导入后的刷新），则跳过
    if (mounted && !_suppressAutoEnterSelection) {
      final newState = ref.read(enterpriseSearchProvider);
      if (!newState.isSelectionMode &&
          newState.hasResults &&
          newState.results.any((e) => !e.isLocal)) {
        ref.read(enterpriseSearchProvider.notifier).enterSelectionMode();
      }
    }
    
    // 重置抑制标志
    _suppressAutoEnterSelection = false;
  }

  /// 搜索前记录 WebView URL 状态
  Future<void> _logQccUrlBeforeSearch(String keyword) async {
    final dataSource = ref.read(enterpriseDataSourceProvider);
    if (dataSource.sourceId != 'qcc') return;

    final controller =
        _webViewController ?? ref.read(webViewControllerProvider);

    if (controller == null) {
      debugPrint('[企查查] 搜索前URL检查: controller=null, keyword="$keyword"');
      return;
    }

    try {
      final url = await controller.getUrl();
      String? href;
      try {
        final jsValue = await controller.evaluateJavascript(
          source: 'location.href',
        );
        href = jsValue?.toString();
      } catch (_) {}

      debugPrint(
        '[企查查] 搜索前URL检查: keyword="$keyword", viewIndex=$_currentViewIndex, '
        'url="${url?.toString() ?? 'null'}", href="${href ?? 'null'}"',
      );
    } catch (e) {
      debugPrint('[企查查] 搜索前URL检查失败: $e');
    }
  }

  void _onEnterpriseSelected(Enterprise enterprise) {
    // 如果是企查查来源且数据不完整，跳转到详情页抓取完整信息
    if (enterprise.source == 'qcc' && enterprise.needsDetailFetch) {
      _fetchDetailAndImport(enterprise);
      return;
    }

    ref.read(enterpriseWebProvider.notifier).setPendingEnterprise(enterprise);
    _showPreviewSheet();
  }

  /// 跳转到详情页抓取完整信息后导入
  Future<void> _fetchDetailAndImport(Enterprise enterprise) async {
    // 检查 WebView 控制器是否就绪
    if (_webViewController == null) {
      debugPrint('[企查查] WebView 控制器未就绪，无法跳转详情页');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先打开企查查页面'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 构建详情页 URL
    final detailUrl = 'https://www.qcc.com/firm/${enterprise.id}.html';

    // 设置自动提取标志
    setState(() {
      _pendingAutoExtract = true;
    });

    debugPrint('[企查查] 开始跳转详情页: $detailUrl');

    // 显示加载提示
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正在获取完整企业信息...'),
          duration: Duration(seconds: 3),
        ),
      );
    }

    // 在后台 WebView 中加载详情页，不切换视图（保持搜索界面）
    // _showWebView();  // 注释掉：不再切换到 WebView 视图
    await _webViewController!.loadUrl(
      urlRequest: URLRequest(url: WebUri(detailUrl)),
    );

    // 设置超时定时器（20秒后如果还没提取成功，提示用户手动操作）
    _autoExtractTimeoutTimer?.cancel();
    _autoExtractTimeoutTimer = Timer(const Duration(seconds: 20), () {
      if (_pendingAutoExtract && mounted) {
        debugPrint('[企查查] 自动提取超时');
        setState(() {
          _pendingAutoExtract = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('页面加载较慢，请稍后点击"导入CRM"按钮手动提取'),
            duration: Duration(seconds: 5),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
  }

  /// 自动提取详情页数据
  Future<void> _autoExtractDetailData() async {
    if (_webViewController == null || !mounted) return;

    debugPrint('[企查查] 开始自动提取详情页数据');

    try {
      // 先注入提取脚本
      await _webViewController!.evaluateJavascript(
        source: _dataSource.extractDataJs,
      );

      // 等待 DOM 渲染完成后执行提取
      await Future.delayed(const Duration(milliseconds: 500));

      // 再次检查状态
      if (!mounted || !_pendingAutoExtract) {
        debugPrint('[企查查] 提取前状态已变化，跳过');
        return;
      }

      // 调用提取函数并通过 handler 回调
      await _webViewController!.evaluateJavascript(
        source: '''
        (function() {
          try {
            if (typeof window.__extractEnterpriseData === 'function') {
              const data = window.__extractEnterpriseData();
              if (data && data.name) {
                window.flutter_inappwebview.callHandler('onEnterpriseData', JSON.stringify(data));
              } else {
                window.flutter_inappwebview.callHandler('onError', '提取数据为空，请手动点击导入按钮');
              }
            } else {
              window.flutter_inappwebview.callHandler('onError', '提取脚本未加载，请手动点击导入按钮');
            }
          } catch (e) {
            window.flutter_inappwebview.callHandler('onError', '提取失败: ' + e.toString());
          }
        })();
      ''',
      );
    } catch (e) {
      debugPrint('[企查查] 自动提取异常: $e');
      // 异常时重置状态，让超时定时器处理
      if (mounted && _pendingAutoExtract) {
        setState(() {
          _pendingAutoExtract = false;
        });
        _autoExtractTimeoutTimer?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('自动提取失败: $e'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  void _showPreviewSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const EnterprisePreviewSheet(),
    ).whenComplete(() {
      final state = ref.read(enterpriseWebProvider);
      if (state.pendingEnterprise != null &&
          state.importResult?.isSuccess != true) {
        ref.read(enterpriseWebProvider.notifier).cancelImport();
      }
    });
  }

  /// 检测是否为登录页面
  bool _isLoginPage(String url) {
    return url.contains('passport.baidu.com') ||
        url.contains('passport.qcc.com') ||
        url.contains('login') ||
        url.contains('signin') ||
        url.contains('user_login');
  }

  /// 注入 JavaScript
  Future<void> _injectScripts() async {
    if (_webViewController == null) return;

    final dataSource = _dataSource;
    await _webViewController!.evaluateJavascript(
      source: dataSource.extractDataJs,
    );
    await _webViewController!.evaluateJavascript(
      source: dataSource.injectButtonJs,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dataSource = ref.watch(enterpriseDataSourceProvider);
    final searchState = ref.watch(enterpriseSearchProvider);

    // 监听搜索状态变化（合并所有状态监听）
    ref.listen<EnterpriseSearchState>(enterpriseSearchProvider, (
      previous,
      next,
    ) {
      // 只在当前页面处理状态变化
      if (ModalRoute.of(context)?.isCurrent != true) return;
      
      // 1. 处理重新搜索错误
      if (previous?.reSearchError == null && next.reSearchError != null) {
        final error = next.reSearchError!;
        final userMessage = error.getUserMessage();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
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
      
      // 2. 重新搜索完成时自动进入选择模式
      final reSearchCompleted =
          previous?.isReSearching == true && next.isReSearching == false;

      if (reSearchCompleted &&
          !next.isSelectionMode &&
          next.hasResults &&
          next.results.any((e) => !e.isLocal)) {
        ref.read(enterpriseSearchProvider.notifier).enterSelectionMode();
      }
      
      // 3. 处理批量导入状态变化
      // 开始导入时显示进度对话框
      if (previous?.isBatchImporting == false && next.isBatchImporting) {
        _showBatchImportProgressDialog();
      }

      // 导入完成时关闭进度对话框并显示结果
      if (previous?.isBatchImporting == true && !next.isBatchImporting) {
        // 确保当前路由仍是本页面，且可以 pop（有对话框）
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(); // 关闭进度对话框
        }
        _showBatchImportSummaryDialog(next);
        
        // 如果导入成功，设置抑制标志，避免刷新后再次自动进入选择模式
        if (next.importErrors.isEmpty) {
          _suppressAutoEnterSelection = true;
        }
      }
    });

    return PopScope(
      canPop: _currentViewIndex == 0 && !searchState.isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        
        // 优先处理选择模式的返回
        if (searchState.isSelectionMode) {
          ref.read(enterpriseSearchProvider.notifier).exitSelectionMode();
          return;
        }
        
        // 处理 WebView 视图的返回
        if (_currentViewIndex == 1) {
          _showSearchView();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            searchState.isSelectionMode
                ? '选择企业'
                : (_currentViewIndex == 0 ? '企业搜索' : dataSource.displayName),
          ),
          leading: _currentViewIndex == 1
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _showSearchView,
                )
              : null,
          actions: [
            // 非选择模式下，显示"选择"按钮
            if (!searchState.isSelectionMode &&
                searchState.hasResults &&
                searchState.results.any((e) => !e.isLocal))
              TextButton(
                onPressed: () {
                  FocusScope.of(context).unfocus(); // 关闭键盘
                  ref.read(enterpriseSearchProvider.notifier).enterSelectionMode();
                },
                child: const Text('选择'),
              ),
            
            if (_currentViewIndex == 0 && !searchState.isSelectionMode)
              IconButton(
                icon: const Icon(Icons.web),
                onPressed: _showWebView,
                tooltip: '打开${dataSource.displayName}（登录/手动操作）',
              ),
            if (_currentViewIndex == 1) ...[
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _webViewController?.reload(),
                tooltip: '刷新',
              ),
              IconButton(
                icon: const Icon(Icons.download_outlined),
                onPressed: _injectScripts,
                tooltip: '提取企业信息',
              ),
            ],
          ],
          bottom: _currentViewIndex == 1 && _webViewLoading
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    value: _webViewProgress / 100,
                    minHeight: 3,
                    backgroundColor: Colors.transparent,
                  ),
                )
              : null,
        ),
        // WebView 始终保持 attach 且有非零尺寸，通过 Opacity 控制可见性
        // 避免使用 Offstage，因为它会导致 WebView 暂停 JS 执行
        body: Stack(
          children: [
            // WebView 始终存在且有尺寸，通过 Opacity 控制可见性
            // 使用 opacity: 0.0 完全隐藏 WebView，但保持其活跃状态以执行 JS 搜索
            // 注意：不能使用 Offstage，因为它会导致 WebView 暂停 JS 执行
            Positioned.fill(
              child: Opacity(
                opacity: _currentViewIndex == 1 ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: _currentViewIndex != 1,
                  child: _buildWebView(),
                ),
              ),
            ),
            // 搜索视图在顶层，通过条件渲染控制
            if (_currentViewIndex == 0)
              Positioned.fill(child: _buildSearchView(theme)),
          ],
        ),
        // 底部选择栏
        bottomNavigationBar: searchState.isSelectionMode
            ? SelectionBar(
                selectedCount: searchState.selectedCount,
                isAllSelected: searchState.isAllSelected,
                onCancel: () {
                  ref.read(enterpriseSearchProvider.notifier).exitSelectionMode();
                },
                onSelectAll: () {
                  ref.read(enterpriseSearchProvider.notifier).toggleSelectAll();
                },
                onBatchImport: () => _showBatchImportConfirmation(),
              )
            : null,
      ),
    );
  }

  /// 显示批量导入确认对话框
  Future<void> _showBatchImportConfirmation() async {
    final searchState = ref.read(enterpriseSearchProvider);
    final selectedCount = searchState.selectedCount;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认批量导入'),
        content: Text('确定要导入选中的 $selectedCount 个企业吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(enterpriseSearchProvider.notifier).batchImport();
    }
  }

  /// 显示批量导入进度对话框
  void _showBatchImportProgressDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('正在导入'),
          content: Consumer(
            builder: (context, ref, _) {
              final searchState = ref.watch(enterpriseSearchProvider);
              final progress = searchState.importTotal > 0
                  ? searchState.importProgress / searchState.importTotal
                  : 0.0;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 16),
                  Text(
                    '${searchState.importProgress} / ${searchState.importTotal}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// 显示批量导入结果摘要对话框
  void _showBatchImportSummaryDialog(EnterpriseSearchState state) {
    final successCount = state.importTotal - state.importErrors.length;
    final failCount = state.importErrors.length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入完成'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '成功: $successCount / ${state.importTotal}',
                style: TextStyle(
                  color: successCount > 0 ? Colors.green : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (failCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '失败: $failCount',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '失败企业:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...state.importErrors.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${e.enterprise.name}: ${e.error}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 构建搜索视图
  Widget _buildSearchView(ThemeData theme) {
    final searchState = ref.watch(enterpriseSearchProvider);
    
    return Column(
      children: [
        if (_showClipboardHint && !searchState.isSelectionMode) _buildClipboardHint(),
        
        // 搜索框（非选择模式下显示）
        if (!searchState.isSelectionMode)
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
        Expanded(child: _buildSearchResults()),
      ],
    );
  }

  /// 构建 WebView
  Widget _buildWebView() {
    final dataSource = ref.watch(enterpriseDataSourceProvider);

    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(dataSource.startUrl)),
      initialSettings: _webViewSettings,
      onWebViewCreated: (controller) {
        _webViewController = controller;

        // 注册 JavaScript 回调
        controller.addJavaScriptHandler(
          handlerName: 'onEnterpriseData',
          callback: (args) {
            if (!mounted) return;
            if (args.isNotEmpty) {
              final json = args.first as String? ?? '{}';
              debugPrint(
                '[企查查] onEnterpriseData 收到数据: ${json.substring(0, json.length > 200 ? 200 : json.length)}...',
              );

              // 重置自动提取状态
              if (_pendingAutoExtract) {
                setState(() {
                  _pendingAutoExtract = false;
                });
                _autoExtractTimeoutTimer?.cancel();
              }

              ref
                  .read(enterpriseWebProvider.notifier)
                  .onEnterpriseCaptured(json);
              _showPreviewSheet();
            }
          },
        );

        controller.addJavaScriptHandler(
          handlerName: 'onError',
          callback: (args) {
            if (!mounted) return;
            final error = args.isNotEmpty ? args.first.toString() : '未知错误';
            debugPrint('[企查查] onError: $error');

            // 重置自动提取状态
            if (_pendingAutoExtract) {
              setState(() {
                _pendingAutoExtract = false;
              });
              _autoExtractTimeoutTimer?.cancel();
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('提取失败: $error'),
                backgroundColor: Colors.orange,
              ),
            );
          },
        );

        // 注册企查查搜索结果回调
        controller.addJavaScriptHandler(
          handlerName: 'onQichachaSearchResult',
          callback: (args) {
            if (args.length < 2) return;

            final requestIdRaw = args[0];
            final requestId = requestIdRaw is num
                ? requestIdRaw.toInt()
                : int.tryParse(requestIdRaw.toString());
            if (requestId == null) return;

            final completerMap = ref.read(qichachaSearchCompleterProvider);
            final completer = completerMap[requestId];
            if (completer == null || completer.isCompleted) return;

            try {
              final jsonStr = args[1] as String? ?? '[]';
              if (jsonStr.isEmpty) {
                // 返回空列表（使用 List<dynamic> 兼容 Completer<Object>）
                completer.complete(<dynamic>[]);
                return;
              }

              final decoded = jsonDecode(jsonStr);

              // 处理 List 类型（搜索结果）
              if (decoded is List) {
                // 直接传递 List<Map>，Repository 侧会处理类型转换
                completer.complete(decoded);
                return;
              }

              // 处理 Map 类型（needNavigate 状态）
              if (decoded is Map) {
                final needNavigate =
                    decoded['needNavigate'] == true ||
                    decoded['needNavigate']?.toString() == 'true';
                if (needNavigate) {
                  completer.complete(<String, Object?>{
                    'needNavigate': true,
                    'targetUrl': decoded['targetUrl']?.toString() ?? '',
                  });
                  return;
                }
                // 其他 Map 类型也直接传递
                completer.complete(decoded);
                return;
              }

              completer.completeError('解析企查查搜索结果失败: unsupported payload');
            } catch (e) {
              completer.completeError('解析企查查搜索结果失败: $e');
            }
          },
        );

        controller.addJavaScriptHandler(
          handlerName: 'onQichachaSearchError',
          callback: (args) {
            if (args.length < 2) return;

            final requestIdRaw = args[0];
            final requestId = requestIdRaw is num
                ? requestIdRaw.toInt()
                : int.tryParse(requestIdRaw.toString());
            if (requestId == null) return;

            final completerMap = ref.read(qichachaSearchCompleterProvider);
            final completer = completerMap[requestId];
            if (completer == null || completer.isCompleted) return;

            final error = (args[1] != null && args[1].toString().isNotEmpty)
                ? args[1].toString()
                : '企查查搜索失败';
            completer.completeError(error);
          },
        );

        // 注册调试日志 handler
        controller.addJavaScriptHandler(
          handlerName: 'onQccDebug',
          callback: (args) {
            if (args.isNotEmpty) {
              debugPrint('[QCC-DEBUG] ${args.join(" ")}');
            }
          },
        );

        // 将 controller 写入 provider
        ref.read(webViewControllerProvider.notifier).state = controller;
        _webViewInitialized = true;
      },
      onProgressChanged: (controller, progress) {
        setState(() {
          _webViewProgress = progress;
          _webViewLoading = progress < 100;
        });
      },
      // 捕获 JS console.log 输出用于调试
      onConsoleMessage: (controller, consoleMessage) {
        final msg = consoleMessage.message;
        // 只打印 QCC-DEBUG 相关的日志
        if (msg.contains('QCC-DEBUG')) {
          debugPrint('[WebView Console] $msg');
        }
      },
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final url = navigationAction.request.url?.toString() ?? '';
        final uri = navigationAction.request.url;

        if (uri != null) {
          final scheme = uri.scheme.toLowerCase();
          if (scheme != 'http' &&
              scheme != 'https' &&
              scheme != 'about' &&
              scheme != 'data' &&
              scheme != 'javascript') {
            debugPrint('[WebView] Blocked custom scheme: $url');
            return NavigationActionPolicy.CANCEL;
          }

          // 拦截移动版 m.qcc.com，重定向到桌面版 www.qcc.com
          if (uri.host == 'm.qcc.com') {
            final desktopUrl = url.replaceFirst('m.qcc.com', 'www.qcc.com');
            debugPrint('[WebView] 重定向移动版到桌面版: $url -> $desktopUrl');
            controller.loadUrl(urlRequest: URLRequest(url: WebUri(desktopUrl)));
            return NavigationActionPolicy.CANCEL;
          }
        }

        if (_isLoginPage(url)) {
          ref.read(enterpriseWebProvider.notifier).markSessionExpired();
        } else {
          ref.read(enterpriseWebProvider.notifier).clearSessionExpired();
        }

        return NavigationActionPolicy.ALLOW;
      },
      onLoadStop: (controller, url) async {
        final currentUrl = url?.toString() ?? '';
        final currentDataSource = ref.read(enterpriseDataSourceProvider);

        debugPrint(
          '[企查查] onLoadStop: url=$currentUrl, pendingAutoExtract=$_pendingAutoExtract',
        );

        if (currentDataSource.isDetailPage(currentUrl)) {
          await _injectScripts();

          // 如果是从搜索结果跳转过来的，自动提取数据
          if (_pendingAutoExtract) {
            debugPrint('[企查查] 检测到详情页加载完成，开始自动提取数据');
            // 延迟等待 DOM 渲染完成
            await Future.delayed(const Duration(milliseconds: 800));

            // 延迟后再次检查状态（可能已被超时或其他操作重置）
            if (!mounted || !_pendingAutoExtract) {
              debugPrint('[企查查] 延迟后状态已变化，跳过自动提取');
              return;
            }

            await _autoExtractDetailData();
          }
        }
      },
    );
  }

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

  Widget _buildSearchResults() {
    final searchState = ref.watch(enterpriseSearchProvider);

    if (searchState.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (searchState.hasError) {
      final error = searchState.error!;
      final dataSource = ref.read(enterpriseDataSourceProvider);
      final dataSourceName = dataSource.displayName;

      // WebView 页面已关闭或未就绪 - 引导用户打开 WebView
      if (error.contains('已关闭') ||
          error.contains('请先打开') ||
          error.contains('未就绪')) {
        return _buildActionableError(
          message: error,
          buttonText: '打开$dataSourceName',
          icon: Icons.open_in_browser,
          onPressed: () {
            _showWebView();
          },
        );
      }

      if (error.contains('登录') || error.contains('验证')) {
        return _buildActionableError(
          message: error,
          buttonText: '去登录/验证',
          icon: Icons.login,
          onPressed: _showWebView,
        );
      }

      return _buildActionableError(
        message: error,
        buttonText: '重试',
        icon: Icons.refresh,
        onPressed: () => _performSearch(_searchController.text.trim()),
      );
    }

    if (!searchState.hasResults) {
      if (_searchController.text.trim().length >= 2) {
        return _buildEmptyState(
          icon: Icons.search_off,
          title: '未找到相关企业',
          subtitle: '数据源: ${searchState.dataSourceLabel ?? '未知'}',
        );
      }
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
          : () async {
              // 获取当前输入框的值，确保与搜索关键词同步
              final keyword = _searchController.text.trim();
              if (keyword.length < 2) {
                // 关键词太短，触发错误提示
                ref
                    .read(enterpriseSearchProvider.notifier)
                    .reSearchExternal(keyword: keyword);
                return;
              }

              final currentState = ref.read(enterpriseSearchProvider);
              // 如果输入框的值与 state.keyword 不一致，先执行一次完整搜索
              if (keyword != currentState.keyword) {
                await _performSearch(keyword);
                if (!mounted) return;
              }

              // 检查最新状态，确保可以执行外部搜索
              final latestState = ref.read(enterpriseSearchProvider);
              if (latestState.canReSearch && !latestState.isReSearching) {
                await ref
                    .read(enterpriseSearchProvider.notifier)
                    .reSearchExternal(keyword: keyword);
              }
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
