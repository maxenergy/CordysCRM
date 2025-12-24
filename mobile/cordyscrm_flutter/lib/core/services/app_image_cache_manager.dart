import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_perf_config.dart';

/// 应用级图片缓存管理器
///
/// 根据平台配置提供差异化的图片缓存策略：
/// - 桌面平台：更大的缓存容量和更长的有效期
/// - 移动平台：适中的缓存容量和较短的有效期
///
/// 使用 flutter_cache_manager 管理网络图片的磁盘缓存。
class AppImageCacheManager extends CacheManager {
  AppImageCacheManager(AppPerfConfig config)
      : super(
          Config(
            'cordys_image_cache',
            stalePeriod: config.imageCacheStalePeriod,
            maxNrOfCacheObjects: config.imageCacheMaxObjects,
          ),
        );
}

/// 图片缓存管理器 Provider
final appImageCacheManagerProvider = Provider<AppImageCacheManager>((ref) {
  final config = ref.read(appPerfConfigProvider);
  return AppImageCacheManager(config);
});
