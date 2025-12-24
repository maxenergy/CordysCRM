import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/platform_service.dart';

/// 性能相关配置（按平台区分）
///
/// 根据不同平台（桌面/移动）提供差异化的性能参数配置。
/// 桌面平台通常拥有更大的屏幕、内存和存储空间，因此可以使用更大的缓存和分页大小。
class AppPerfConfig {
  AppPerfConfig(this._platform);

  final PlatformService _platform;

  /// 列表分页大小
  ///
  /// - 桌面：50 条/页（更大屏幕可显示更多内容）
  /// - 移动：20 条/页（保持流畅滚动体验）
  int get pageSize {
    if (_platform.isDesktop) return 50;
    return 20;
  }

  /// 图片缓存条目上限
  ///
  /// - 桌面：300 个（更大存储空间）
  /// - 移动：120 个（节省存储空间）
  int get imageCacheMaxObjects {
    if (_platform.isDesktop) return 300;
    return 120;
  }

  /// 图片磁盘缓存有效期
  ///
  /// - 桌面：30 天（减少网络请求）
  /// - 移动：7 天（避免占用过多存储）
  Duration get imageCacheStalePeriod {
    if (_platform.isDesktop) return const Duration(days: 30);
    return const Duration(days: 7);
  }

  /// 内存图片缓存尺寸（宽高）建议值
  ///
  /// 用于 CachedNetworkImage 的 memCacheWidth/Height 参数。
  /// - 桌面：1024px（支持高分辨率显示）
  /// - 移动：512px（平衡质量和内存占用）
  int get imageMemCacheSize {
    if (_platform.isDesktop) return 1024;
    return 512;
  }

  /// 全局 Flutter imageCache 条目上限
  ///
  /// 用于设置 PaintingBinding.instance.imageCache.maximumSize
  /// - 桌面：200 个
  /// - 移动：100 个
  int get imageCacheMaxEntries {
    if (_platform.isDesktop) return 200;
    return 100;
  }

  /// 全局 Flutter imageCache 字节上限
  ///
  /// 用于设置 PaintingBinding.instance.imageCache.maximumSizeBytes
  /// - 桌面：100 MB
  /// - 移动：60 MB
  int get imageCacheMaxBytes {
    if (_platform.isDesktop) return 100 * 1024 * 1024;
    return 60 * 1024 * 1024;
  }

  /// 平台名称（便于日志和调试）
  String get platformName => _platform.platformName;
}

/// 性能配置 Provider
final appPerfConfigProvider = Provider<AppPerfConfig>((ref) {
  final platform = ref.read(platformServiceProvider);
  return AppPerfConfig(platform);
});
