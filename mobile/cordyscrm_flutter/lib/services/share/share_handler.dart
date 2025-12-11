import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// 爱企查链接解析结果
class AiqichaLinkResult {
  const AiqichaLinkResult({
    required this.companyId,
    required this.originalUrl,
  });

  /// 企业 ID
  final String companyId;

  /// 原始 URL
  final String originalUrl;
}

/// 分享处理服务
///
/// 负责监听和处理从其他应用分享到本应用的内容，
/// 主要用于接收爱企查企业详情页链接并跳转到 WebView。
class ShareHandler {
  ShareHandler({required this.router});

  /// 路由实例
  final GoRouter router;

  /// 媒体流订阅
  StreamSubscription<List<SharedMediaFile>>? _mediaStreamSubscription;

  /// 爱企查链接正则表达式
  /// 匹配格式: aiqicha.baidu.com/company_detail_XXXXXXXX
  static final RegExp _aiqichaLinkRegex = RegExp(
    r'aiqicha\.baidu\.com/company_detail_(\d+)',
    caseSensitive: false,
  );

  /// 初始化分享监听
  ///
  /// 应在应用启动时调用，监听两种场景：
  /// 1. 应用因分享而启动（冷启动）
  /// 2. 应用在前台时接收分享（热启动）
  void initialize() {
    // 监听应用运行时接收到的分享
    _mediaStreamSubscription =
        ReceiveSharingIntent.instance.getMediaStream().listen(
      _handleSharedMedia,
      onError: (error) {
        debugPrint('[ShareHandler] Stream error: $error');
      },
    );

    // 处理应用因分享而启动时的内容
    ReceiveSharingIntent.instance.getInitialMedia().then(_handleSharedMedia);
  }

  /// 释放资源
  void dispose() {
    _mediaStreamSubscription?.cancel();
    _mediaStreamSubscription = null;
  }

  /// 处理分享的媒体内容
  void _handleSharedMedia(List<SharedMediaFile> sharedMedia) {
    if (sharedMedia.isEmpty) {
      return;
    }

    for (final media in sharedMedia) {
      // 检查是否为文本类型
      if (media.type == SharedMediaType.text ||
          media.type == SharedMediaType.url) {
        final text = media.path;
        debugPrint('[ShareHandler] Received: $text');

        // 尝试解析爱企查链接
        final result = parseAiqichaLink(text);
        if (result != null) {
          _navigateToEnterprise(result);
          // 重置分享意图，避免重复处理
          ReceiveSharingIntent.instance.reset();
          return;
        }
      }
    }
  }

  /// 解析爱企查链接
  ///
  /// 从文本中提取爱企查企业详情页链接的企业 ID。
  /// 支持的链接格式：
  /// - https://aiqicha.baidu.com/company_detail_12345678
  /// - aiqicha.baidu.com/company_detail_12345678.html
  ///
  /// 返回 [AiqichaLinkResult] 如果解析成功，否则返回 null。
  static AiqichaLinkResult? parseAiqichaLink(String text) {
    final match = _aiqichaLinkRegex.firstMatch(text);
    if (match == null || match.groupCount < 1) {
      return null;
    }

    final companyId = match.group(1);
    if (companyId == null || companyId.isEmpty) {
      return null;
    }

    // 提取完整的 URL
    final urlMatch = RegExp(
      r'https?://[^\s]+aiqicha\.baidu\.com/company_detail_\d+[^\s]*',
      caseSensitive: false,
    ).firstMatch(text);

    final originalUrl = urlMatch?.group(0) ??
        'https://aiqicha.baidu.com/company_detail_$companyId';

    return AiqichaLinkResult(
      companyId: companyId,
      originalUrl: originalUrl,
    );
  }

  /// 导航到企业详情页
  void _navigateToEnterprise(AiqichaLinkResult result) {
    debugPrint('[ShareHandler] Navigating to company: ${result.companyId}');
    debugPrint('[ShareHandler] URL: ${result.originalUrl}');

    // 跳转到企业 WebView 页面，传递初始 URL
    router.go('/enterprise', extra: result.originalUrl);
  }
}
