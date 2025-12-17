import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/datasources/enterprise_data_source.dart';
import 'enterprise_provider.dart';
import 'widgets/enterprise_preview_sheet.dart';

/// 企业信息 WebView 页面
///
/// 支持多数据源（企查查、爱企查等），通过 [enterpriseDataSourceProvider] 获取当前数据源。
/// 可通过 [initialUrl] 参数指定初始加载的 URL（用于分享接收）。
class EnterpriseWebViewPage extends ConsumerStatefulWidget {
  const EnterpriseWebViewPage({
    super.key,
    this.initialUrl,
  });

  /// 初始加载的 URL
  ///
  /// 如果为 null，则加载当前数据源的首页。
  /// 用于从其他应用分享链接时直接打开指定企业详情页。
  final String? initialUrl;

  @override
  ConsumerState<EnterpriseWebViewPage> createState() =>
      _EnterpriseWebViewPageState();
}

class _EnterpriseWebViewPageState extends ConsumerState<EnterpriseWebViewPage> {
  InAppWebViewController? _controller;
  bool _isInitialized = false;

  // WebView 配置
  final InAppWebViewSettings _settings = InAppWebViewSettings(
    useShouldOverrideUrlLoading: true,
    javaScriptEnabled: true,
    domStorageEnabled: true,
    mediaPlaybackRequiresUserGesture: false,
    allowsInlineMediaPlayback: true,
    useHybridComposition: true,
  );

  /// 获取当前数据源
  EnterpriseDataSourceInterface get _dataSource =>
      ref.read(enterpriseDataSourceProvider);

  /// 检测是否为登录页面
  ///
  /// 支持百度系（爱企查）和企查查的登录页面检测。
  bool _isLoginPage(String url) {
    return url.contains('passport.baidu.com') ||
        url.contains('passport.qcc.com') ||
        url.contains('login') ||
        url.contains('signin') ||
        url.contains('user_login');
  }

  /// 注入 JavaScript
  ///
  /// 使用当前数据源的 extractDataJs 和 injectButtonJs。
  Future<void> _injectScripts() async {
    if (_controller == null) return;

    final dataSource = _dataSource;
    await _controller!.evaluateJavascript(source: dataSource.extractDataJs);
    await _controller!.evaluateJavascript(source: dataSource.injectButtonJs);
  }

  /// 显示导入预览弹窗
  void _showPreviewSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const EnterprisePreviewSheet(),
    ).whenComplete(() {
      // 弹窗关闭时清除待导入状态（如果未成功导入）
      final state = ref.read(enterpriseWebProvider);
      if (state.pendingEnterprise != null && state.importResult?.isSuccess != true) {
        ref.read(enterpriseWebProvider.notifier).cancelImport();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(enterpriseWebProvider);
    final dataSource = ref.watch(enterpriseDataSourceProvider);

    // 监听状态变化，显示预览弹窗
    ref.listen(enterpriseWebProvider, (prev, next) {
      // 防止 prev 为 null 的情况
      final prevState = prev ?? const EnterpriseWebState();

      // 当有新的待导入企业时显示弹窗
      if (prevState.pendingEnterprise == null && next.pendingEnterprise != null) {
        _showPreviewSheet();
      }

      // 显示错误提示
      if (next.error != null && prevState.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: '关闭',
              textColor: Colors.white,
              onPressed: () =>
                  ref.read(enterpriseWebProvider.notifier).clearError(),
            ),
          ),
        );
      }

      // 显示会话过期提示
      if (!prevState.sessionExpired && next.sessionExpired) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('会话已过期'),
            content: Text('请重新登录${dataSource.displayName}账号'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  ref
                      .read(enterpriseWebProvider.notifier)
                      .clearSessionExpired();
                },
                child: const Text('知道了'),
              ),
            ],
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(dataSource.displayName),
        actions: [
          // 刷新按钮
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller?.reload(),
            tooltip: '刷新',
          ),
          // 手动提取按钮
          IconButton(
            icon: const Icon(Icons.download_outlined),
            onPressed: _injectScripts,
            tooltip: '提取企业信息',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: state.isLoading
              ? LinearProgressIndicator(
                  value: state.progress / 100,
                  minHeight: 3,
                  backgroundColor: Colors.transparent,
                )
              : const SizedBox(height: 3),
        ),
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri(widget.initialUrl ?? dataSource.startUrl),
        ),
        initialSettings: _settings,
        onWebViewCreated: (controller) async {
          _controller = controller;
          
          // 将控制器注册到 Provider，供 Repository 使用
          ref.read(webViewControllerProvider.notifier).state = controller;

          // 注册 JavaScript 回调
          controller.addJavaScriptHandler(
            handlerName: 'onEnterpriseData',
            callback: (args) {
              if (args.isNotEmpty) {
                final json = args.first as String? ?? '{}';
                ref
                    .read(enterpriseWebProvider.notifier)
                    .onEnterpriseCaptured(json);
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
          
          // 注册爱企查搜索结果回调
          controller.addJavaScriptHandler(
            handlerName: 'onAiqichaSearchResult',
            callback: (args) {
              final completer = ref.read(aiqichaSearchCompleterProvider);
              if (completer == null || completer.isCompleted) return;
              
              try {
                if (args.isEmpty) {
                  completer.complete([]);
                  return;
                }
                
                final jsonStr = args.first as String? ?? '[]';
                final list = (jsonDecode(jsonStr) as List<dynamic>)
                    .map((e) => Map<String, String>.from(
                        (e as Map<String, dynamic>).map((k, v) => MapEntry(k, v?.toString() ?? ''))))
                    .toList();
                completer.complete(list);
              } catch (e) {
                completer.completeError('解析搜索结果失败: $e');
              }
            },
          );
          
          // 注册爱企查搜索错误回调
          controller.addJavaScriptHandler(
            handlerName: 'onAiqichaSearchError',
            callback: (args) {
              final completer = ref.read(aiqichaSearchCompleterProvider);
              if (completer == null || completer.isCompleted) return;
              
              final error = args.isNotEmpty ? args.first.toString() : '搜索失败';
              completer.completeError(error);
            },
          );

          // 加载保存的 Cookie（在 WebView 创建后立即加载）
          if (!_isInitialized) {
            await ref.read(enterpriseWebProvider.notifier).loadCookies();
            _isInitialized = true;
            // 重新加载页面以应用 Cookie
            controller.reload();
          }
        },
        onProgressChanged: (controller, progress) {
          ref.read(enterpriseWebProvider.notifier).setProgress(progress);
        },
        shouldOverrideUrlLoading: (controller, navigationAction) async {
          final url = navigationAction.request.url?.toString() ?? '';

          // 检测登录页面
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

          // 在企业详情页注入脚本（使用数据源的 isDetailPage 方法）
          if (currentDataSource.isDetailPage(currentUrl)) {
            await _injectScripts();
          }

          // 只有在初始化完成后才保存 Cookie 和 User-Agent
          // 避免在 loadCookies() -> reload() 期间把空 Cookie 写回
          if (!_isInitialized) return;

          // 获取并保存 WebView 的真实 User-Agent（用于 Dio 请求）
          final userAgent = await controller.evaluateJavascript(
            source: 'navigator.userAgent',
          );
          if (userAgent != null && userAgent is String && userAgent.isNotEmpty) {
            // JS 返回的字符串可能带引号，需要清理
            String cleanUA = userAgent;
            if (cleanUA.startsWith('"') && cleanUA.endsWith('"')) {
              cleanUA = cleanUA.substring(1, cleanUA.length - 1);
            }
            if (cleanUA.isNotEmpty) {
              await ref.read(enterpriseRepositoryProvider).saveUserAgent(cleanUA);
            }
          }

          // 保存 Cookie（包括爱企查和百度 Passport 域名）
          // 只有当 Cookie 非空时才保存，避免覆盖已有的有效 Cookie
          final aiqichaCookies = await CookieManager.instance().getCookies(
            url: WebUri('https://aiqicha.baidu.com'),
          );
          final passportCookies = await CookieManager.instance().getCookies(
            url: WebUri('https://passport.baidu.com'),
          );
          
          // 检查是否有有效的登录 Cookie（BDUSS 是百度登录的关键 Cookie）
          final hasValidSession = aiqichaCookies.any((c) => c.name == 'BDUSS') ||
              passportCookies.any((c) => c.name == 'BDUSS');
          
          if (aiqichaCookies.isNotEmpty || passportCookies.isNotEmpty) {
            final cookieMap = <String, String>{};
            for (final c in aiqichaCookies) {
              cookieMap['aiqicha_${c.name}'] = c.value;
            }
            for (final c in passportCookies) {
              cookieMap['passport_${c.name}'] = c.value;
            }
            // 只有当有有效会话或 Cookie 数量足够时才保存
            if (hasValidSession || cookieMap.length > 5) {
              await ref.read(enterpriseWebProvider.notifier).saveCookies(cookieMap);
            }
          }
        },
        onReceivedHttpError: (controller, request, response) {
          final statusCode = response.statusCode ?? 0;
          if (statusCode == 401 || statusCode == 403) {
            ref.read(enterpriseWebProvider.notifier).markSessionExpired();
          }
        },
      ),
    );
  }
}
