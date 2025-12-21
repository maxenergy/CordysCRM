import 'dart:async';
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

  @override
  void dispose() {
    debugPrint('[WebView] dispose() called, clearing controller reference');
    
    // 清空 WebViewController 引用，避免 Repository 继续使用已销毁的 controller
    // 注意：必须在 super.dispose() 之前调用，因为之后 ref 可能不可用
    try {
      ref.read(webViewControllerProvider.notifier).state = null;
      debugPrint('[WebView] Controller reference cleared');
    } catch (e) {
      debugPrint('[WebView] Failed to clear controller: $e');
    }

    // 清理未完成的爱企查搜索 completer
    try {
      final aiqichaCompleter = ref.read(aiqichaSearchCompleterProvider);
      if (aiqichaCompleter != null && !aiqichaCompleter.isCompleted) {
        aiqichaCompleter.completeError('WebView disposed');
      }
      ref.read(aiqichaSearchCompleterProvider.notifier).state = null;
    } catch (e) {
      debugPrint('[WebView] Failed to clear aiqicha completer: $e');
    }

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
          <int, Completer<List<Map<String, String>>>>{};
    } catch (e) {
      debugPrint('[WebView] Failed to clear qcc completers: $e');
    }

    super.dispose();
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

          // 注册 JavaScript 回调（必须在将 controller 写入 provider 之前完成，
          // 避免 Repository 立即使用 controller 时 handler 尚未注册的窗口期）
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

          // 注册企查查搜索结果回调（支持 requestId 关联）
          controller.addJavaScriptHandler(
            handlerName: 'onQichachaSearchResult',
            callback: (args) {
              // 参数格式：[requestId, jsonStr]
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
                  completer.complete([]);
                  return;
                }
                
                final list = (jsonDecode(jsonStr) as List<dynamic>)
                    .map((e) => Map<String, String>.from(
                        (e as Map<String, dynamic>).map((k, v) => MapEntry(k, v?.toString() ?? ''))))
                    .toList();
                completer.complete(list);
              } catch (e) {
                completer.completeError('解析企查查搜索结果失败: $e');
              }
            },
          );
          
          // 注册企查查搜索错误回调（支持 requestId 关联）
          controller.addJavaScriptHandler(
            handlerName: 'onQichachaSearchError',
            callback: (args) {
              // 参数格式：[requestId, errorMsg]
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

          // 注册企查查调试日志回调
          controller.addJavaScriptHandler(
            handlerName: 'onQccDebug',
            callback: (args) {
              final message = args.isNotEmpty ? args.first.toString() : '';
              debugPrint('[QCC JS] $message');
            },
          );

          // 所有 handlers 注册完毕后，将 controller 写入 provider
          // 这样 Repository 使用 controller 时，handlers 已经就绪
          ref.read(webViewControllerProvider.notifier).state = controller;

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
          final uri = navigationAction.request.url;

          // 拦截自定义 URL scheme（如 qichacha://, aiqicha://, weixin:// 等）
          // 这些是 App 唤起链接，WebView 无法处理
          if (uri != null) {
            final scheme = uri.scheme.toLowerCase();
            // 只允许 http, https, about, data 等标准 scheme
            if (scheme != 'http' && 
                scheme != 'https' && 
                scheme != 'about' && 
                scheme != 'data' &&
                scheme != 'javascript') {
              // 阻止加载自定义 scheme，避免 ERR_UNKNOWN_URL_SCHEME 错误
              debugPrint('[WebView] Blocked custom scheme: $url');
              return NavigationActionPolicy.CANCEL;
            }
          }

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
