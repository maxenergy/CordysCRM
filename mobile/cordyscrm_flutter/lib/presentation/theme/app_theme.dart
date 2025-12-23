import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/platform_service.dart';

/// 应用主题配置
class AppTheme {
  AppTheme._();

  /// 主色调
  static const Color primaryColor = Color(0xFF1677FF);
  static const Color primaryColorLight = Color(0xFF4096FF);
  static const Color primaryColorDark = Color(0xFF0958D9);

  /// 功能色
  static const Color successColor = Color(0xFF52C41A);
  static const Color warningColor = Color(0xFFFAAD14);
  static const Color errorColor = Color(0xFFFF4D4F);
  static const Color infoColor = Color(0xFF1677FF);

  /// 中性色
  static const Color textPrimary = Color(0xFF1F1F1F);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textTertiary = Color(0xFF999999);
  static const Color borderColor = Color(0xFFD9D9D9);
  static const Color dividerColor = Color(0xFFF0F0F0);
  static const Color backgroundColor = Color(0xFFF5F5F5);

  /// 平台相关间距 - 移动端
  static const EdgeInsets _mobilePadding = EdgeInsets.all(16);
  static const double _mobileSpacing = 12;
  static const double _mobileItemSpacing = 8;

  /// 平台相关间距 - 桌面端
  static const EdgeInsets _desktopPadding = EdgeInsets.all(24);
  static const double _desktopSpacing = 16;
  static const double _desktopItemSpacing = 12;

  /// 获取平台相关的页面内边距
  static EdgeInsets pagePadding(WidgetRef ref) {
    final isDesktop = ref.read(platformServiceProvider).isDesktop;
    return isDesktop ? _desktopPadding : _mobilePadding;
  }

  /// 获取平台相关的区块间距
  static double sectionSpacing(WidgetRef ref) {
    final isDesktop = ref.read(platformServiceProvider).isDesktop;
    return isDesktop ? _desktopSpacing : _mobileSpacing;
  }

  /// 获取平台相关的列表项间距
  static double itemSpacing(WidgetRef ref) {
    final isDesktop = ref.read(platformServiceProvider).isDesktop;
    return isDesktop ? _desktopItemSpacing : _mobileItemSpacing;
  }

  /// 获取亮色主题（需要平台信息）
  static ThemeData lightTheme(bool isDesktop) => _buildLightTheme(isDesktop);

  /// 获取暗色主题（需要平台信息）
  static ThemeData darkTheme(bool isDesktop) => _buildDarkTheme(isDesktop);

  /// 构建亮色主题
  static ThemeData _buildLightTheme(bool isDesktop) => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: primaryColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: backgroundColor,
        // 桌面端 hover 效果颜色
        hoverColor: primaryColor.withValues(alpha: 0.08),
        focusColor: primaryColor.withValues(alpha: 0.12),
        splashColor: primaryColor.withValues(alpha: 0.16),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: textPrimary,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        // ListTile hover 效果
        listTileTheme: ListTileThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 16 : 12,
            vertical: isDesktop ? 8 : 4,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 16 : 12,
            vertical: isDesktop ? 14 : 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: errorColor),
          ),
          hintStyle: const TextStyle(color: textTertiary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, isDesktop ? 44 : 48),
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24 : 16,
              vertical: isDesktop ? 12 : 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ).copyWith(
            // 桌面端 hover 效果
            overlayColor: WidgetStateProperty.resolveWith<Color?>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.hovered)) {
                  return Colors.white.withValues(alpha: 0.1);
                }
                if (states.contains(WidgetState.pressed)) {
                  return Colors.white.withValues(alpha: 0.2);
                }
                return null;
              },
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryColor,
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 16 : 12,
              vertical: isDesktop ? 10 : 8,
            ),
          ).copyWith(
            // 桌面端 hover 效果
            overlayColor: WidgetStateProperty.resolveWith<Color?>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.hovered)) {
                  return primaryColor.withValues(alpha: 0.08);
                }
                if (states.contains(WidgetState.pressed)) {
                  return primaryColor.withValues(alpha: 0.16);
                }
                return null;
              },
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryColor,
            side: const BorderSide(color: borderColor),
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 16 : 12,
              vertical: isDesktop ? 10 : 8,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ).copyWith(
            // 桌面端 hover 效果
            overlayColor: WidgetStateProperty.resolveWith<Color?>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.hovered)) {
                  return primaryColor.withValues(alpha: 0.08);
                }
                if (states.contains(WidgetState.pressed)) {
                  return primaryColor.withValues(alpha: 0.16);
                }
                return null;
              },
            ),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: dividerColor,
          thickness: 1,
          space: 1,
        ),
      );

  /// 构建暗色主题
  static ThemeData _buildDarkTheme(bool isDesktop) => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: primaryColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF141414),
        // 桌面端 hover 效果颜色
        hoverColor: primaryColor.withValues(alpha: 0.08),
        focusColor: primaryColor.withValues(alpha: 0.12),
        splashColor: primaryColor.withValues(alpha: 0.16),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1F1F1F),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1F1F1F),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        // ListTile hover 效果
        listTileTheme: ListTileThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 16 : 12,
            vertical: isDesktop ? 8 : 4,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1F1F1F),
          contentPadding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 16 : 12,
            vertical: isDesktop ? 14 : 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF434343)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF434343)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, isDesktop ? 44 : 48),
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24 : 16,
              vertical: isDesktop ? 12 : 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ).copyWith(
            overlayColor: WidgetStateProperty.resolveWith<Color?>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.hovered)) {
                  return Colors.white.withValues(alpha: 0.1);
                }
                if (states.contains(WidgetState.pressed)) {
                  return Colors.white.withValues(alpha: 0.2);
                }
                return null;
              },
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryColor,
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 16 : 12,
              vertical: isDesktop ? 10 : 8,
            ),
          ).copyWith(
            overlayColor: WidgetStateProperty.resolveWith<Color?>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.hovered)) {
                  return primaryColor.withValues(alpha: 0.08);
                }
                if (states.contains(WidgetState.pressed)) {
                  return primaryColor.withValues(alpha: 0.16);
                }
                return null;
              },
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryColor,
            side: const BorderSide(color: Color(0xFF434343)),
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 16 : 12,
              vertical: isDesktop ? 10 : 8,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ).copyWith(
            overlayColor: WidgetStateProperty.resolveWith<Color?>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.hovered)) {
                  return primaryColor.withValues(alpha: 0.08);
                }
                if (states.contains(WidgetState.pressed)) {
                  return primaryColor.withValues(alpha: 0.16);
                }
                return null;
              },
            ),
          ),
        ),
      );
}
