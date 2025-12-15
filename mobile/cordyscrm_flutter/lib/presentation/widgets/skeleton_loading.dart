import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_theme.dart';

/// 客户列表骨架屏
/// 
/// 在数据加载时显示，提供更好的用户体验
class CustomerListSkeleton extends StatelessWidget {
  const CustomerListSkeleton({
    super.key,
    this.itemCount = 5,
    this.padding = const EdgeInsets.only(top: 8, bottom: 80),
  });

  /// 骨架项数量
  final int itemCount;
  
  /// 列表内边距
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    // 使用 Column + List.generate 避免嵌套滚动容器问题
    return SingleChildScrollView(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: List.generate(
          itemCount,
          (index) => const ListItemSkeleton(),
        ),
      ),
    );
  }
}

/// 单个列表项骨架
/// 
/// 模拟客户列表项布局：头像、名称、联系人、状态标签
class ListItemSkeleton extends StatelessWidget {
  const ListItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[700]! : AppTheme.dividerColor;
    final highlightColor = isDark ? Colors.grey[600]! : AppTheme.backgroundColor;
    final skeletonColor = isDark ? Colors.grey[800]! : AppTheme.dividerColor;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppTheme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头像骨架
              _SkeletonCircle(size: 44, color: skeletonColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 名称骨架
                    _SkeletonBox(height: 16, radius: 4, color: skeletonColor),
                    const SizedBox(height: 10),
                    // 联系人和状态标签骨架
                    Row(
                      children: [
                        Expanded(
                          child: _SkeletonBox(height: 12, radius: 4, color: skeletonColor),
                        ),
                        const SizedBox(width: 12),
                        _SkeletonBox(width: 64, height: 20, radius: 4, color: skeletonColor),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 分页加载骨架（用于加载更多时显示）
class PageLoadingSkeleton extends StatelessWidget {
  const PageLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: ListItemSkeleton(),
    );
  }
}

/// 矩形骨架块
class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    this.width,
    required this.height,
    required this.radius,
    required this.color,
  });

  final double? width;
  final double height;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// 圆形骨架块
class _SkeletonCircle extends StatelessWidget {
  const _SkeletonCircle({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
