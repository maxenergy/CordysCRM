# 企业搜索批量导入 UI 修复报告

## 问题描述

用户反馈：企业搜索完成后，看到了搜索结果列表和复选框，但是：
1. 顶部 AppBar 的"选择"按钮没有出现
2. 底部的批量导入操作栏（SelectionBar）也没有出现

## 根本原因分析

通过与 Gemini MCP 协作分析，发现问题的根本原因是：

### 1. SelectionBar 被系统导航栏遮挡（核心问题）

- `SelectionBar` 使用固定高度（`height: 60`）且没有使用 `SafeArea`
- 在现代全面屏手机（iOS 底部横条或 Android 手势导航）上，屏幕底部的 34px+ 区域是系统保留区
- 由于 `SelectionBar` 强制固定 60px 高度且未适配安全区域，它会被渲染在屏幕的最底部
- 导致内容完全被系统的 Home Indicator（小黑条）遮挡或沉浸在系统导航栏下方
- 用户因此看不到操作栏

### 2. 键盘遮挡问题

- 用户在输入搜索词后键盘通常是打开的
- 进入选择模式时如果键盘未关闭，也会遮挡底部操作栏

### 3. "选择"按钮消失是正常行为

- 代码逻辑：`if (!searchState.isSelectionMode ...)` 显示按钮
- 当用户通过**长按**列表项进入选择模式时，`isSelectionMode` 变为 `true`
- 此时，App Bar 上的"选择"按钮自动隐藏（因为它只在非选择模式下显示），这是正确的

## 修复方案

### 1. 修复 SelectionBar（适配 SafeArea）

**文件**: `mobile/cordyscrm_flutter/lib/presentation/features/enterprise/widgets/selection_bar.dart`

**修改内容**:
- 移除外层 `Container` 的固定高度
- 改用 `SafeArea` 包裹内容
- 确保操作栏位于系统底部导航栏之上

```dart
// 修改前
return Container(
  height: 60, // ❌ 问题所在：固定高度且无 SafeArea
  decoration: ...,
  child: Padding(...)
);

// 修改后
return Container(
  decoration: ...,
  child: SafeArea( // ✅ 新增：适配底部安全区域
    child: SizedBox(
      height: 60, // 内容高度保持 60，但整体高度会自动增加 padding.bottom
      child: Padding(...)
    ),
  ),
);
```

### 2. 进入选择模式时自动收起键盘

**文件 1**: `mobile/cordyscrm_flutter/lib/presentation/features/enterprise/widgets/enterprise_search_result_item.dart`

**修改内容**: 长按触发选择模式时关闭键盘

```dart
void handleLongPress() {
  if (!isSelectionMode) {
    FocusScope.of(context).unfocus(); // ✅ 新增：长按时关闭键盘
    ref.read(enterpriseSearchProvider.notifier)
        .enterSelectionMode(initialSelectedId: enterprise.creditCode);
  }
}
```

**文件 2**: `mobile/cordyscrm_flutter/lib/presentation/features/enterprise/enterprise_search_page.dart`

**修改内容**: 点击"选择"按钮时关闭键盘

```dart
TextButton(
  onPressed: () {
    FocusScope.of(context).unfocus(); // ✅ 新增：点击选择时关闭键盘
    ref.read(enterpriseSearchProvider.notifier).enterSelectionMode();
  },
  child: const Text('选择'),
),
```

## 测试步骤

修复后，请按以下步骤验证：

1. **安装新版本 APK**
   ```bash
   adb install -r mobile/cordyscrm_flutter/build/app/outputs/flutter-apk/app-release.apk
   ```

2. **测试场景 1：长按进入选择模式**
   - 输入关键词搜索（确保键盘弹出）
   - 直接长按某一个搜索结果
   - **预期结果**：
     - 键盘自动收起
     - 复选框出现
     - 底部出现带有"取消"和"批量导入"的操作栏
     - 操作栏位于屏幕可视范围内（Home Indicator 上方）
     - 顶部"选择"按钮消失，标题变为"选择企业"

3. **测试场景 2：点击"选择"按钮进入选择模式**
   - 输入关键词搜索
   - 点击顶部 AppBar 的"选择"按钮
   - **预期结果**：
     - 键盘自动收起
     - 复选框出现
     - 底部操作栏可见
     - 标题变为"选择企业"

4. **测试场景 3：批量导入流程**
   - 进入选择模式
   - 点击底部的"全选" Checkbox
   - 点击"批量导入"按钮
   - **预期结果**：
     - 显示确认对话框
     - 确认后显示进度对话框
     - 完成后显示结果摘要

5. **测试场景 4：退出选择模式**
   - 进入选择模式
   - 点击底部的"取消"按钮
   - **预期结果**：
     - 复选框消失
     - 底部操作栏消失
     - 顶部"选择"按钮重新出现
     - 标题变回"企业搜索"

## 技术细节

### SafeArea 的作用

`SafeArea` 是 Flutter 提供的一个 Widget，用于自动适配设备的安全区域：
- 在 iOS 上，避开顶部的刘海和底部的 Home Indicator
- 在 Android 上，避开系统导航栏和状态栏
- 自动添加必要的 padding，确保内容不被系统 UI 遮挡

### 为什么使用 SizedBox 而不是直接设置 Container 高度

```dart
SafeArea(
  child: SizedBox(
    height: 60, // 内容区域高度
    child: ...
  ),
)
```

这样做的好处：
- `SizedBox` 的 60px 是内容区域的高度
- `SafeArea` 会在底部自动添加系统安全区域的 padding（通常 34px）
- 最终整体高度 = 60px + 底部安全区域高度
- 确保内容始终在可视区域内

## Git 提交信息

```
fix(flutter): 修复企业搜索批量导入 UI 显示问题

- 修复 SelectionBar 在全面屏手机上被系统导航栏遮挡的问题
- 添加 SafeArea 适配底部安全区域
- 进入选择模式时自动关闭键盘，避免遮挡底部操作栏
- 优化用户体验，确保批量导入操作栏始终可见

问题分析：
用户反馈搜索完成后看到复选框但看不到批量导入操作栏。
根本原因是 SelectionBar 使用固定高度且未适配安全区域，
导致在现代全面屏手机上被系统 Home Indicator 遮挡。

解决方案：
1. SelectionBar 使用 SafeArea 包裹内容
2. 进入选择模式时调用 FocusScope.unfocus() 关闭键盘
3. 保持内容高度 60px，整体高度自动增加底部安全区域 padding
```

## 相关文件

- `mobile/cordyscrm_flutter/lib/presentation/features/enterprise/widgets/selection_bar.dart`
- `mobile/cordyscrm_flutter/lib/presentation/features/enterprise/widgets/enterprise_search_result_item.dart`
- `mobile/cordyscrm_flutter/lib/presentation/features/enterprise/enterprise_search_page.dart`

## 构建信息

- APK 路径: `mobile/cordyscrm_flutter/build/app/outputs/flutter-apk/app-release.apk`
- APK 大小: 66.6MB
- 构建时间: 83.4s
- Git Commit: b306be404
