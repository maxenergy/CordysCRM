# Design Document: Flutter Dependency Fix

## Overview

本设计文档描述了修复 Flutter Android 构建失败的技术方案。核心问题是 `file_picker` 插件版本过旧，使用了已废弃的 v1 embedding API。解决方案是升级 `file_picker` 及其他相关依赖到兼容版本。

## Root Cause Analysis

### 错误信息

```
/home/rogers/.pub-cache/hosted/pub.dev/file_picker-6.2.1/android/src/main/java/com/mr/flutter/plugin/filepicker/FilePickerPlugin.java:25: error: cannot find symbol
import io.flutter.plugin.common.PluginRegistry.Registrar;
                                       ^
  symbol:   class Registrar
  location: interface PluginRegistry
```

### 原因

1. Flutter 在较新版本中移除了 v1 embedding API (`PluginRegistry.Registrar`)
2. `file_picker` 6.2.1 仍在使用 v1 embedding API
3. `file_picker` 10.3.8 已迁移到 v2 embedding API，兼容当前 Flutter 版本

## Solution Architecture

### 升级策略

采用 **保守升级** 策略：
1. 首先升级 `file_picker` 到最新版本（10.3.8）
2. 运行 `flutter pub upgrade` 自动解决依赖冲突
3. 检查是否有 API 破坏性变更
4. 如有必要，更新受影响的代码

### 依赖版本对比

| Package | Current | Target | Breaking Changes |
|---------|---------|--------|------------------|
| file_picker | 6.2.1 | 10.3.8 | 可能有 API 变更 |
| connectivity_plus | 5.0.2 | 7.0.0 | 可能有 API 变更 |
| firebase_core | 2.32.0 | 4.3.0 | 可能有 API 变更 |
| flutter_riverpod | 2.6.1 | 3.0.3 | 可能有 API 变更 |

### 风险评估

**高风险依赖**：
- `flutter_riverpod` 2.x → 3.x：可能有状态管理 API 变更
- `firebase_core` 2.x → 4.x：可能有初始化 API 变更

**低风险依赖**：
- `file_picker`：主要是内部实现变更，公共 API 应保持兼容

## Implementation Plan

### Phase 1: 依赖升级

```bash
# 1. 清理构建缓存
flutter clean

# 2. 升级依赖
flutter pub upgrade

# 3. 重新获取依赖
flutter pub get
```

### Phase 2: 代码兼容性检查

检查以下文件是否需要更新：

1. **adaptive_file_picker.dart**
   - 检查 `FilePicker.platform.pickFiles()` API 是否变更
   - 检查 `FilePickerResult` 类型是否变更

2. **Riverpod 相关代码**（如果升级到 3.x）
   - 检查 `StateNotifier` 是否废弃
   - 检查 Provider 声明语法是否变更

3. **Firebase 相关代码**（如果升级到 4.x）
   - 检查 `Firebase.initializeApp()` 调用
   - 检查 `FirebaseMessaging` API

### Phase 3: 构建验证

```bash
# 1. 分析代码
flutter analyze

# 2. 尝试构建（不运行）
flutter build apk --debug

# 3. 如果成功，在真机上运行
flutter run -d <device_id>
```

## Fallback Strategy

如果 `flutter pub upgrade` 导致大量破坏性变更：

### 选项 1: 选择性升级

只升级 `file_picker`，锁定其他依赖版本：

```yaml
dependencies:
  file_picker: ^10.3.8  # 升级
  flutter_riverpod: 2.6.1  # 锁定
  firebase_core: 2.32.0  # 锁定
```

### 选项 2: 使用兼容版本

查找 `file_picker` 的中间版本（如 8.x 或 9.x），既支持 v2 embedding 又不引入太多破坏性变更。

## Testing Strategy

### 构建测试

1. **编译测试**：`flutter build apk --debug` 无错误
2. **分析测试**：`flutter analyze` 无警告

### 功能测试

1. **文件选择测试**：
   - 打开文件选择器
   - 选择图片文件
   - 验证文件路径正确返回

2. **集成测试**：
   - 启动应用
   - 登录后端
   - 测试数据同步功能

## Rollback Plan

如果升级失败：

1. 恢复 `pubspec.yaml` 和 `pubspec.lock`：
   ```bash
   git checkout pubspec.yaml pubspec.lock
   flutter pub get
   ```

2. 考虑降级 Flutter SDK 版本（不推荐）

3. 寻找替代的文件选择插件
