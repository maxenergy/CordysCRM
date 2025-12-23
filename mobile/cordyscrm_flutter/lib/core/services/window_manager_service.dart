import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// 窗口管理服务
/// 
/// 负责桌面平台的窗口初始化、状态保存和恢复。
/// 仅在 Windows、macOS、Linux 平台生效。
class WindowManagerService with WindowListener {
  // SharedPreferences keys
  static const _kPrefWidth = 'window_width';
  static const _kPrefHeight = 'window_height';
  static const _kPrefX = 'window_x';
  static const _kPrefY = 'window_y';
  static const _kPrefMaximized = 'window_maximized';

  // 默认窗口尺寸
  static const Size defaultSize = Size(1200, 800);
  
  // 最小窗口尺寸
  static const Size minSize = Size(800, 600);

  Timer? _saveDebounce;

  /// 检查是否为桌面平台
  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// 初始化窗口管理
  /// 
  /// 设置默认窗口大小、最小尺寸，恢复上次窗口状态，并开始监听窗口事件。
  /// 如果初始化失败，不会阻断应用启动。
  Future<void> initialize() async {
    if (!_isDesktop) return;

    try {
      await windowManager.ensureInitialized();

      // 设置窗口选项
      const windowOptions = WindowOptions(
        size: defaultSize,
        minimumSize: minSize,
        center: true,
        title: 'CordysCRM',
        titleBarStyle: TitleBarStyle.normal,
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        // 恢复窗口状态
        await _restoreWindowState();
        
        // 显示窗口
        await windowManager.show();
        await windowManager.focus();
      });

      // 监听窗口事件
      windowManager.addListener(this);
    } catch (e) {
      // 初始化失败不阻断启动
      debugPrint('[WindowManagerService] 初始化失败: $e');
    }
  }

  /// 恢复窗口状态
  /// 
  /// 从 SharedPreferences 读取上次保存的窗口大小、位置和最大化状态。
  /// 如果数据不合法，使用默认值。
  Future<void> _restoreWindowState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final width = prefs.getDouble(_kPrefWidth);
      final height = prefs.getDouble(_kPrefHeight);
      final x = prefs.getDouble(_kPrefX);
      final y = prefs.getDouble(_kPrefY);
      final maximized = prefs.getBool(_kPrefMaximized) ?? false;

      // 恢复窗口尺寸（确保不小于最小尺寸）
      if (width != null && height != null) {
        final safeWidth = width < minSize.width ? minSize.width : width;
        final safeHeight = height < minSize.height ? minSize.height : height;
        await windowManager.setSize(Size(safeWidth, safeHeight));
      }

      // 恢复窗口位置
      if (x != null && y != null) {
        await windowManager.setPosition(Offset(x, y));
      }

      // 恢复最大化状态
      if (maximized) {
        await windowManager.maximize();
      }
    } catch (e) {
      debugPrint('[WindowManagerService] 恢复窗口状态失败: $e');
    }
  }

  /// 保存窗口状态
  /// 
  /// 将当前窗口的大小、位置和最大化状态保存到 SharedPreferences。
  Future<void> _saveWindowState() async {
    if (!_isDesktop) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final size = await windowManager.getSize();
      final position = await windowManager.getPosition();
      final isMaximized = await windowManager.isMaximized();

      await prefs.setDouble(_kPrefWidth, size.width);
      await prefs.setDouble(_kPrefHeight, size.height);
      await prefs.setDouble(_kPrefX, position.dx);
      await prefs.setDouble(_kPrefY, position.dy);
      await prefs.setBool(_kPrefMaximized, isMaximized);
    } catch (e) {
      debugPrint('[WindowManagerService] 保存窗口状态失败: $e');
    }
  }

  /// 防抖保存窗口状态
  /// 
  /// 避免频繁的窗口事件导致过多的存储操作。
  void _debouncedSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(
      const Duration(milliseconds: 800),
      _saveWindowState,
    );
  }

  // WindowListener 事件回调

  @override
  void onWindowResize() => _debouncedSave();

  @override
  void onWindowMove() => _debouncedSave();

  @override
  void onWindowMaximize() => _debouncedSave();

  @override
  void onWindowUnmaximize() => _debouncedSave();

  @override
  void onWindowClose() async {
    // 窗口关闭前最后保存一次
    await _saveWindowState();
  }

  /// 释放资源
  void dispose() {
    if (_isDesktop) {
      windowManager.removeListener(this);
    }
    _saveDebounce?.cancel();
  }
}
