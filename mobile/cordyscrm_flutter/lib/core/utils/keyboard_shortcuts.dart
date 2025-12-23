import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/platform_service.dart';

/// 键盘快捷键工具类
/// 
/// 提供桌面端常用快捷键的定义和处理。
/// 仅在桌面平台生效。
class KeyboardShortcuts {
  KeyboardShortcuts._();

  /// 创建平台相关的快捷键激活器
  /// 
  /// macOS 使用 Meta 键（Command），Windows/Linux 使用 Control 键
  static SingleActivator _platformShortcut(
    LogicalKeyboardKey key,
    bool isMacOS, {
    bool shift = false,
    bool alt = false,
  }) {
    return SingleActivator(
      key,
      control: !isMacOS,
      meta: isMacOS,
      shift: shift,
      alt: alt,
    );
  }

  /// 获取默认快捷键映射
  static Map<ShortcutActivator, Intent> getDefaultShortcuts(WidgetRef ref) {
    final platformService = ref.read(platformServiceProvider);
    if (!platformService.isDesktop) return {};

    final isMacOS = platformService.platformName == 'macos';

    return {
      // Ctrl/Cmd + N: 新建
      _platformShortcut(LogicalKeyboardKey.keyN, isMacOS): const NewItemIntent(),

      // Ctrl/Cmd + S: 保存
      _platformShortcut(LogicalKeyboardKey.keyS, isMacOS): const SaveIntent(),

      // Ctrl/Cmd + F: 搜索/筛选
      _platformShortcut(LogicalKeyboardKey.keyF, isMacOS): const SearchIntent(),

      // Ctrl/Cmd + R: 刷新
      _platformShortcut(LogicalKeyboardKey.keyR, isMacOS): const RefreshIntent(),

      // Esc: 关闭/返回
      const SingleActivator(LogicalKeyboardKey.escape): const CloseIntent(),
    };
  }

  /// 构建默认 Actions
  /// 
  /// [onNew] 新建回调
  /// [onSave] 保存回调
  /// [onSearch] 搜索回调
  /// [onRefresh] 刷新回调
  /// [onClose] 关闭回调
  static Map<Type, Action<Intent>> buildDefaultActions({
    VoidCallback? onNew,
    VoidCallback? onSave,
    VoidCallback? onSearch,
    VoidCallback? onRefresh,
    VoidCallback? onClose,
  }) {
    return {
      NewItemIntent: CallbackAction<NewItemIntent>(
        onInvoke: (intent) {
          if (_shouldHandleShortcut(intent)) {
            onNew?.call();
          }
          return null;
        },
      ),
      SaveIntent: CallbackAction<SaveIntent>(
        onInvoke: (intent) {
          if (_shouldHandleShortcut(intent)) {
            onSave?.call();
          }
          return null;
        },
      ),
      SearchIntent: CallbackAction<SearchIntent>(
        onInvoke: (intent) {
          if (_shouldHandleShortcut(intent)) {
            onSearch?.call();
          }
          return null;
        },
      ),
      RefreshIntent: CallbackAction<RefreshIntent>(
        onInvoke: (intent) {
          if (_shouldHandleShortcut(intent)) {
            onRefresh?.call();
          }
          return null;
        },
      ),
      CloseIntent: CallbackAction<CloseIntent>(
        onInvoke: (intent) {
          // Esc 键总是允许，即使在文本输入时也可以关闭对话框
          onClose?.call();
          return null;
        },
      ),
    };
  }

  /// 检查是否应该处理快捷键
  /// 
  /// 当文本输入框获得焦点时，某些快捷键（如 Ctrl+F, Ctrl+S）应该被禁用，
  /// 避免与文本编辑操作冲突。
  /// 
  /// 注意：CloseIntent (Esc) 总是允许，因为用户通常期望 Esc 能关闭对话框。
  static bool _shouldHandleShortcut(Intent intent) {
    // CloseIntent 总是允许
    if (intent is CloseIntent) return true;

    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return true;

    // 如果当前焦点是文本输入框，禁用某些快捷键
    final context = focus.context;
    if (context == null) return true;

    // 检查是否为 TextField 或 TextFormField
    final widget = context.widget;
    if (widget is EditableText || widget is TextField || widget is TextFormField) {
      return false;
    }

    return true;
  }
}

// Intent 定义

/// 新建 Intent
class NewItemIntent extends Intent {
  const NewItemIntent();
}

/// 保存 Intent
class SaveIntent extends Intent {
  const SaveIntent();
}

/// 搜索 Intent
class SearchIntent extends Intent {
  const SearchIntent();
}

/// 刷新 Intent
class RefreshIntent extends Intent {
  const RefreshIntent();
}

/// 关闭 Intent
class CloseIntent extends Intent {
  const CloseIntent();
}
