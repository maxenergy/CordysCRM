# SelectionBar 自动显示功能修复

## 问题描述

Flutter Android 应用的"企业搜索"界面，搜索完成后多选/全选/批量导入的 SelectionBar 没有自动出现，用户需要手动点击"选择"按钮才能进入选择模式。

## 根本原因

1. **实际使用的页面是 `EnterpriseSearchWithWebViewPage`**，而不是 `EnterpriseSearchPage`
2. SelectionBar 只在 `isSelectionMode == true` 时显示
3. 进入选择模式需要手动点击"选择"按钮，没有自动进入的逻辑
4. "选择"按钮的显示条件：必须有结果且存在非本地企业

## 解决方案

### 1. 搜索完成后自动进入选择模式

在 `_performSearch()` 方法中添加自动进入选择模式的逻辑：

```dart
Future<void> _performSearch(String keyword) async {
  if (keyword.length < 2) return;
  
  // 新搜索前退出选择模式，避免旧选择污染新结果
  final searchState = ref.read(enterpriseSearchProvider);
  if (searchState.isSelectionMode) {
    ref.read(enterpriseSearchProvider.notifier).exitSelectionMode();
  }
  
  await ref.read(enterpriseSearchProvider.notifier).search(keyword);
  
  // 搜索完成后，如果有可选企业，自动进入选择模式
  // 但如果设置了抑制标志（如批量导入后的刷新），则跳过
  if (mounted && !_suppressAutoEnterSelection) {
    final newState = ref.read(enterpriseSearchProvider);
    if (!newState.isSelectionMode &&
        newState.hasResults &&
        newState.results.any((e) => !e.isLocal)) {
      ref.read(enterpriseSearchProvider.notifier).enterSelectionMode();
    }
  }
  
  // 重置抑制标志
  _suppressAutoEnterSelection = false;
}
```

### 2. 重新搜索完成后也自动进入选择模式

在 `ref.listen` 中监听重新搜索完成事件：

```dart
// 重新搜索完成时自动进入选择模式
final reSearchCompleted =
    previous?.isReSearching == true && next.isReSearching == false;

if (reSearchCompleted &&
    !next.isSelectionMode &&
    next.hasResults &&
    next.results.any((e) => !e.isLocal)) {
  ref.read(enterpriseSearchProvider.notifier).enterSelectionMode();
}
```

### 3. 批量导入后避免再次自动进入

添加 `_suppressAutoEnterSelection` 标志：

```dart
// 如果导入成功，设置抑制标志，避免刷新后再次自动进入选择模式
if (next.importErrors.isEmpty) {
  _suppressAutoEnterSelection = true;
}
```

### 4. 路由保护

在所有状态监听中添加路由保护：

```dart
// 只在当前页面处理状态变化
if (ModalRoute.of(context)?.isCurrent != true) return;
```

### 5. 对话框关闭的双重保护

```dart
// 确保当前路由仍是本页面，且可以 pop（有对话框）
if (ModalRoute.of(context)?.isCurrent == true && 
    Navigator.of(context).canPop()) {
  Navigator.of(context).pop(); // 关闭进度对话框
}
```

## 测试步骤

### 1. 基本搜索测试

1. 打开企业搜索页面
2. 输入企业名称（如"腾讯"）
3. 等待搜索完成
4. **预期结果**：如果有非本地企业，自动进入选择模式，底部显示 SelectionBar

### 2. 本地结果测试

1. 搜索一个只有本地结果的企业
2. **预期结果**：不自动进入选择模式（因为本地企业不可导入）

### 3. 重新搜索测试

1. 搜索一个企业，得到本地结果
2. 点击"搜索企查查"按钮
3. 等待重新搜索完成
4. **预期结果**：如果有外部结果，自动进入选择模式

### 4. 批量导入测试

1. 搜索并进入选择模式
2. 选择几个企业
3. 点击"批量导入"
4. 等待导入完成
5. **预期结果**：导入成功后退出选择模式，刷新结果时不再自动进入

### 5. 页面切换测试

1. 开始搜索
2. 在搜索过程中切换到其他页面
3. **预期结果**：状态变化不会影响其他页面

## 修改文件

- `mobile/cordyscrm_flutter/lib/presentation/features/enterprise/enterprise_search_with_webview_page.dart`

## 相关 Commits

1. `feat(flutter): 搜索完成后自动进入选择模式显示SelectionBar`
2. `fix(flutter): 优化自动进入选择模式的边界处理`
3. `refactor(flutter): 合并状态监听并优化对话框关闭逻辑`
4. `fix(flutter): 加强对话框关闭的双重保护`

## 注意事项

1. **用户体验变化**：搜索完成后会自动隐藏搜索框，用户需要点击"取消"按钮退出选择模式
2. **本地企业不可选**：只有非本地企业才会触发自动进入选择模式
3. **批量导入后的行为**：导入成功后会退出选择模式，避免用户困惑

## 技术细节

### 状态管理

- 使用 Riverpod 的 `StateNotifier` 管理搜索状态
- 通过 `ref.listen` 监听状态变化
- 使用 `_suppressAutoEnterSelection` 标志控制自动进入行为

### 边界处理

1. **新搜索前退出选择模式**：避免旧选择污染新结果
2. **路由保护**：只在当前页面处理状态变化
3. **对话框保护**：双重检查避免误 pop 其他路由
4. **批量导入后抑制**：避免刷新时再次自动进入

### 代码优化

1. **合并监听逻辑**：将多个 `ref.listen` 合并为一个
2. **减少重复注册**：提高性能和可维护性
3. **清晰的注释**：便于后续维护

## 后续优化建议

1. 考虑将 `ref.listen` 移到 `initState` 中，避免在 `build` 中重复注册
2. 可以添加用户设置，允许用户选择是否自动进入选择模式
3. 考虑添加动画效果，使选择模式的进入更加平滑
