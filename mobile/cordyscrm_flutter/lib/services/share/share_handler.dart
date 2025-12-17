import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../core/utils/enterprise_url_utils.dart';
import '../../presentation/features/enterprise/enterprise_provider.dart';
import '../../presentation/routing/app_router.dart';

/// 企业链接解析结果
class EnterpriseLinkResult {
  const EnterpriseLinkResult({
    required this.originalUrl,
    required this.dataSourceType,
  });

  /// 原始 URL
  final String originalUrl;

  /// 数据源类型
  final EnterpriseDataSourceType dataSourceType;
}

/// 分享处理服务
///
/// 负责监听和处理从其他应用分享到本应用的内容，
/// 支持接收企查查和爱企查企业详情页链接并跳转到 WebView。
class ShareHandler {
  ShareHandler({required this.router, required this.container});

  /// 路由实例
  final GoRouter router;

  /// ProviderContainer，用于更新数据源状态
  final ProviderContainer container;

  /// 媒体流订阅
  StreamSubscription<List<SharedMediaFile>>? _mediaStreamSubscription;

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

        // 尝试解析企业信息链接（支持企查查和爱企查）
        final result = parseEnterpriseLink(text);
        if (result != null) {
          _navigateToEnterprise(result);
          // 重置分享意图，避免重复处理
          ReceiveSharingIntent.instance.reset();
          return;
        }
      }
    }
  }

  /// 解析企业信息链接
  ///
  /// 从文本中提取企查查或爱企查企业详情页链接。
  /// 支持的链接格式：
  /// - 企查查: https://www.qcc.com/firm/xxx.html
  /// - 爱企查: https://aiqicha.baidu.com/company_detail_xxx
  ///
  /// 返回 [EnterpriseLinkResult] 如果解析成功，否则返回 null。
  static EnterpriseLinkResult? parseEnterpriseLink(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    // 使用统一的 URL 检测工具检测数据源类型
    final dataSourceType = detectDataSourceFromUrl(trimmed);
    if (dataSourceType == EnterpriseDataSourceType.unknown) {
      return null;
    }

    // 提取完整的 URL
    final urlMatch = RegExp(
      r'https?://[^\s]+',
      caseSensitive: false,
    ).firstMatch(trimmed);

    final originalUrl = urlMatch?.group(0) ?? trimmed;

    return EnterpriseLinkResult(
      originalUrl: originalUrl,
      dataSourceType: dataSourceType,
    );
  }

  /// 导航到企业详情页
  void _navigateToEnterprise(EnterpriseLinkResult result) {
    final sourceName = switch (result.dataSourceType) {
      EnterpriseDataSourceType.qcc => '企查查',
      EnterpriseDataSourceType.iqicha => '爱企查',
      _ => '未知',
    };
    debugPrint('[ShareHandler] Navigating to $sourceName');
    debugPrint('[ShareHandler] URL: ${result.originalUrl}');

    // 更新数据源类型
    container.read(enterpriseDataSourceTypeProvider.notifier).state =
        result.dataSourceType;

    // 跳转到企业 WebView 页面，传递初始 URL 和数据源类型
    router.go(
      AppRoutes.enterprise,
      extra: EnterpriseRouteParams(
        initialUrl: result.originalUrl,
        dataSourceType: result.dataSourceType,
      ),
    );
  }
}
