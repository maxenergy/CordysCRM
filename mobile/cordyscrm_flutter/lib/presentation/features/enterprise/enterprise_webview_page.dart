import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'enterprise_provider.dart';
import 'widgets/enterprise_preview_sheet.dart';

/// 爱企查 WebView 页面
///
/// 加载爱企查网站，支持企业信息提取和导入
class EnterpriseWebViewPage extends ConsumerStatefulWidget {
  const EnterpriseWebViewPage({super.key});

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

  // 注入的 JavaScript - 创建导入按钮
  static const _injectButtonJs = '''
(function() {
  // 防止重复注入
  if (document.getElementById('__crm_import_btn')) return;
  
  // 创建浮动按钮
  const btn = document.createElement('button');
  btn.id = '__crm_import_btn';
  btn.innerHTML = '📥 导入CRM';
  
  // 样式设置
  Object.assign(btn.style, {
    position: 'fixed',
    right: '16px',
    bottom: '80px',
    zIndex: '99999',
    padding: '12px 20px',
    background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
    color: '#fff',
    border: 'none',
    borderRadius: '24px',
    fontSize: '14px',
    fontWeight: '600',
    boxShadow: '0 4px 15px rgba(102, 126, 234, 0.4)',
    cursor: 'pointer',
    transition: 'transform 0.2s, box-shadow 0.2s',
  });
  
  // 悬停效果
  btn.onmouseenter = () => {
    btn.style.transform = 'scale(1.05)';
    btn.style.boxShadow = '0 6px 20px rgba(102, 126, 234, 0.5)';
  };
  btn.onmouseleave = () => {
    btn.style.transform = 'scale(1)';
    btn.style.boxShadow = '0 4px 15px rgba(102, 126, 234, 0.4)';
  };
  
  // 点击事件
  btn.onclick = () => {
    try {
      // 提取企业信息
      const data = window.__extractEnterpriseData();
      window.flutter_inappwebview.callHandler('onEnterpriseData', JSON.stringify(data));
    } catch (e) {
      window.flutter_inappwebview.callHandler('onError', e.toString());
    }
  };
  
  document.body.appendChild(btn);
})();
''';

  // 注入的 JavaScript - 提取企业数据
  static const _extractDataJs = '''
window.__extractEnterpriseData = function() {
  const getText = (sel) => {
    const el = document.querySelector(sel);
    return el ? el.textContent.trim() : '';
  };
  
  const getTextByLabel = (label) => {
    const items = document.querySelectorAll('.info-item, .detail-item, tr');
    for (const item of items) {
      if (item.textContent.includes(label)) {
        const value = item.querySelector('.value, td:last-child, span:last-child');
        if (value) return value.textContent.trim();
      }
    }
    return '';
  };
  
  // 从 URL 提取企业 ID
  const urlMatch = location.href.match(/company_detail_(\\w+)/);
  const pidMatch = location.href.match(/pid=(\\w+)/);
  const id = urlMatch ? urlMatch[1] : (pidMatch ? pidMatch[1] : '');
  
  return {
    id: id,
    name: getText('.company-name, .title h1, h1.name') || getText('h1'),
    creditCode: getTextByLabel('统一社会信用代码') || getTextByLabel('信用代码'),
    legalPerson: getTextByLabel('法定代表人') || getTextByLabel('法人'),
    registeredCapital: getTextByLabel('注册资本'),
    establishDate: getTextByLabel('成立日期') || getTextByLabel('成立时间'),
    status: getTextByLabel('经营状态') || getTextByLabel('状态'),
    address: getTextByLabel('注册地址') || getTextByLabel('地址'),
    industry: getTextByLabel('所属行业') || getTextByLabel('行业'),
    businessScope: getTextByLabel('经营范围'),
    phone: getTextByLabel('电话') || getTextByLabel('联系电话'),
    email: getTextByLabel('邮箱') || getTextByLabel('电子邮箱'),
    website: getTextByLabel('官网') || getTextByLabel('网址'),
  };
};
''';

  /// 检测是否为登录页面
  bool _isLoginPage(String url) {
    return url.contains('passport.baidu.com') ||
        url.contains('login') ||
        url.contains('signin');
  }

  /// 检测是否为企业详情页
  bool _isDetailPage(String url) {
    return url.contains('company_detail') ||
        url.contains('/detail') ||
        (url.contains('aiqicha') && url.contains('pid='));
  }

  /// 注入 JavaScript
  Future<void> _injectScripts() async {
    if (_controller == null) return;

    await _controller!.evaluateJavascript(source: _extractDataJs);
    await _controller!.evaluateJavascript(source: _injectButtonJs);
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
            content: const Text('请重新登录爱企查账号'),
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
        title: const Text('爱企查'),
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
          url: WebUri('https://aiqicha.baidu.com'),
        ),
        initialSettings: _settings,
        onWebViewCreated: (controller) async {
          _controller = controller;

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

          // 在企业详情页注入脚本
          if (_isDetailPage(currentUrl)) {
            await _injectScripts();
          }

          // 保存 Cookie（包括爱企查和百度 Passport 域名）
          final aiqichaCookies = await CookieManager.instance().getCookies(
            url: WebUri('https://aiqicha.baidu.com'),
          );
          final passportCookies = await CookieManager.instance().getCookies(
            url: WebUri('https://passport.baidu.com'),
          );
          final cookieMap = <String, String>{};
          for (final c in aiqichaCookies) {
            cookieMap['aiqicha_${c.name}'] = c.value;
          }
          for (final c in passportCookies) {
            cookieMap['passport_${c.name}'] = c.value;
          }
          await ref.read(enterpriseWebProvider.notifier).saveCookies(cookieMap);
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
