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
      _webViewController?.loadUrl(
        urlRequest: URLRequest(url: WebUri(content)),
      );
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
    // 搜索前记录 WebView URL 状态，便于调试
    await _logQccUrlBeforeSearch(keyword)
        .timeout(const Duration(milliseconds: 500), onTimeout: () {});
    await ref.read(enterpriseSearchProvider.notifier).search(keyword);
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
        final jsValue =
            await controller.evaluateJavascript(source: 'location.href');
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
    ref.read(enterpriseWebProvider.notifier).setPendingEnterprise(enterprise);
    _showPreviewSheet();
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
    await _webViewController!.evaluateJavascript(source: dataSource.extractDataJs);
    await _webViewController!.evaluateJavascript(source: dataSource.injectButtonJs);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dataSource = ref.watch(enterpriseDataSourceProvider);

    return PopScope(
      canPop: _currentViewIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentViewIndex == 1) {
          _showSearchView();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_currentViewIndex == 0 ? '企业搜索' : dataSource.displayName),
          leading: _currentViewIndex == 1
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _showSearchView,
                )
              : null,
          actions: [
            if (_currentViewIndex == 0)
              IconButton(
                icon: const Icon(Icons.open_in_browser),
                onPressed: _showWebView,
                tooltip: '打开${dataSource.displayName}',
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
            Positioned.fill(
              child: Opacity(
                opacity: _currentViewIndex == 1 ? 1.0 : 0.01,
                child: IgnorePointer(
                  ignoring: _currentViewIndex != 1,
                  child: _buildWebView(),
                ),
              ),
            ),
            // 搜索视图在顶层，通过条件渲染控制
            if (_currentViewIndex == 0)
              Positioned.fill(
                child: _buildSearchView(theme),
              ),
          ],
        ),
      ),
    );
  }

  /// 构建搜索视图
  Widget _buildSearchView(ThemeData theme) {
    return Column(
      children: [
        if (_showClipboardHint) _buildClipboardHint(),
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
              fillColor:
                  theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
      initialUrlRequest: URLRequest(
        url: WebUri(dataSource.startUrl),
      ),
      initialSettings: _webViewSettings,
      onWebViewCreated: (controller) {
        _webViewController = controller;

        // 注册 JavaScript 回调
        controller.addJavaScriptHandler(
          handlerName: 'onEnterpriseData',
          callback: (args) {
            if (args.isNotEmpty) {
              final json = args.first as String? ?? '{}';
              ref.read(enterpriseWebProvider.notifier).onEnterpriseCaptured(json);
              _showPreviewSheet();
            }
          },
        );

        controller.addJavaScriptHandler(
          handlerName: 'onError',
          callback: (args) {
            final error = args.isNotEmpty ? args.first.toString() : '未知错误';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('提取失败: $error')),
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
                final needNavigate = decoded['needNavigate'] == true ||
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
            controller.loadUrl(
              urlRequest: URLRequest(url: WebUri(desktopUrl)),
            );
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

        if (currentDataSource.isDetailPage(currentUrl)) {
          await _injectScripts();
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
      final dataSourceName =
          dataSourceType == EnterpriseDataSourceType.qcc ? '企查查' : '爱企查';
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
          Text(title, style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
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
        ],
      ),
    );
  }
}
