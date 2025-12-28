# SelectionBar 显示问题修复报告

## 问题描述

Flutter Android 应用的"企业搜索"界面，搜索完成后多选/全选/批量导入的 SelectionBar 没有出现。

## 问题根源

通过与 Codex MCP 协作分析，发现问题的根本原因是：

**路由配置使用了错误的页面组件！**

在 `app_router.dart` 中，企业搜索路由指向的是 `EnterpriseSearchWithWebViewPage`：
```dart
GoRoute(
  path: AppRoutes.enterpriseSearch,
  name: 'enterpriseSearch',
  builder: (context, state) => const EnterpriseSearchWithWebViewPage(),
),
```

但是，SelectionBar 和批量导入的所有逻辑都在 `EnterpriseSearchPage` 中实现，而 `EnterpriseSearchWithWebViewPage` **完全没有**这些功能！

## 解决方案

将 SelectionBar 相关的逻辑从 `EnterpriseSearchPage` 迁移到 `EnterpriseSearchWithWebViewPage` 中。

### 修改内容

#### 1. 添加 SelectionBar 导入
```dart
import 'widgets/selection_bar.dart';
```

#### 2. 修改 AppBar
- 添加"选择"按钮（显示条件：非选择模式 && 有搜索结果 && 有非本地企业）
- 选择模式下标题显示"选择企业"

#### 3. 添加底部 SelectionBar
```dart
bottomNavigationBar: searchState.isSelectionMode
    ? SelectionBar(
        selectedCount: searchState.selectedCount,
        isAllSelected: searchState.isAllSelected,
        onCancel: () {
          ref.read(enterpriseSearchProvider.notifier).exitSelectionMode();
        },
        onSelectAll: () {
          ref.read(enterpriseSearchProvider.notifier).toggleSelectAll();
        },
        onBatchImport: () => _showBatchImportConfirmation(),
      )
    : null,
```

#### 4. 添加批量导入对话框
- `_showBatchImportConfirmation()` - 确认对话框
- `_showBatchImportProgressDialog()` - 进度对话框
- `_showBatchImportSummaryDialog()` - 结果摘要对话框

#### 5. 修改 PopScope 处理
```dart
return PopScope(
  canPop: _currentViewIndex == 0 && !searchState.isSelectionMode,
  onPopInvokedWithResult: (didPop, result) {
    if (didPop) return;
    
    // 优先处理选择模式的返回
    if (searchState.isSelectionMode) {
      ref.read(enterpriseSearchProvider.notifier).exitSelectionMode();
      return;
    }
    
    // 处理 WebView 视图的返回
    if (_currentViewIndex == 1) {
      _showSearchView();
    }
  },
```

#### 6. 添加批量导入状态监听
```dart
// 监听批量导入状态变化
ref.listen<EnterpriseSearchState>(enterpriseSearchProvider, (
  previous,
  next,
) {
  // 开始导入时显示进度对话框
  if (previous?.isBatchImporting == false && next.isBatchImporting) {
    _showBatchImportProgressDialog();
  }

  // 导入完成时关闭进度对话框并显示结果
  if (previous?.isBatchImporting == true && !next.isBatchImporting) {
    if (ModalRoute.of(context)?.isCurrent == true) {
      Navigator.of(context).pop();
      _showBatchImportSummaryDialog(next);
    }
  }
});
```

#### 7. 修改搜索视图
- 选择模式下隐藏剪贴板提示
- 选择模式下隐藏搜索框

## 测试步骤

1. **启动应用并登录**
   ```bash
   cd mobile/cordyscrm_flutter
   flutter run
   ```

2. **进入企业搜索页面**
   - 点击底部导航栏的"企业搜索"

3. **执行搜索**
   - 输入企业名称（如"腾讯"）
   - 等待搜索结果

4. **验证"选择"按钮**
   - 确认 AppBar 右侧出现"选择"按钮
   - 按钮仅在有非本地企业时显示

5. **进入选择模式**
   - 点击"选择"按钮
   - 确认：
     - AppBar 标题变为"选择企业"
     - 底部出现 SelectionBar
     - SelectionBar 显示"取消"、"全选"和"批量导入"按钮

6. **测试选择功能**
   - 点击企业列表项进行选择/取消选择
   - 确认 SelectionBar 的选中计数正确更新
   - 测试"全选"按钮
   - 测试"取消"按钮退出选择模式

7. **测试批量导入**
   - 选择若干企业
   - 点击"批量导入"按钮
   - 确认显示确认对话框
   - 点击"确认"
   - 确认显示进度对话框
   - 等待导入完成
   - 确认显示结果摘要对话框

8. **测试返回键**
   - 在选择模式下按返回键
   - 确认退出选择模式而不是退出页面

## 关键改进

1. **正确的页面组件**：修复了路由配置与实际功能不匹配的问题
2. **完整的选择模式**：包含进入、退出、全选、批量导入等完整功能
3. **良好的用户体验**：
   - 选择模式下隐藏不必要的 UI 元素
   - 返回键优先退出选择模式
   - 批量导入有完整的进度反馈
4. **状态管理**：正确使用 Riverpod 监听状态变化并更新 UI

## 相关文件

- `lib/presentation/features/enterprise/enterprise_search_with_webview_page.dart` - 主要修改
- `lib/presentation/features/enterprise/widgets/selection_bar.dart` - SelectionBar 组件
- `lib/presentation/features/enterprise/enterprise_provider.dart` - 状态管理
- `lib/presentation/routing/app_router.dart` - 路由配置

## 技术要点

1. **Riverpod 状态监听**：使用 `ref.listen` 监听批量导入状态变化
2. **PopScope 处理**：正确处理返回键在不同模式下的行为
3. **对话框管理**：确保对话框在正确的时机显示和关闭
4. **条件渲染**：根据选择模式动态显示/隐藏 UI 元素

## 后续优化建议

1. 考虑添加批量导入的撤销功能
2. 优化批量导入的性能（并发导入）
3. 添加批量导入的断点续传功能
4. 考虑将选择模式逻辑抽取为可复用的 mixin 或组件
