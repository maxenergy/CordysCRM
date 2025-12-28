# 企业搜索选择模式调试指南

## 问题描述

用户报告在企业搜索完成后，"全选"按钮和"批量导入"操作栏没有出现。

## 根本原因分析

### 1. "选择"按钮显示条件

在 `enterprise_search_page.dart` 中，"选择"按钮的显示条件为：

```dart
if (!searchState.isSelectionMode &&
    searchState.hasResults &&
    searchState.results.any((e) => !e.isLocal))
```

这意味着必须满足以下所有条件：
- 不在选择模式下
- 有搜索结果
- **至少有一个非本地企业（`isLocal == false`）**

### 2. `isLocal` 字段的判断逻辑

在 `enterprise.dart` 中：

```dart
bool get isLocal => source == 'local';
```

企业的 `source` 字段决定了 `isLocal` 的值：
- `source == 'local'` → `isLocal == true` → 不可选择
- `source == 'qcc'` → `isLocal == false` → 可选择
- `source == 'iqicha'` → `isLocal == false` → 可选择

### 3. 可能的问题场景

**场景 A：所有搜索结果都是本地企业**
- 如果搜索关键词匹配的企业都已经在本地数据库中
- 所有结果的 `source == 'local'`
- "选择"按钮不会显示（符合预期）

**场景 B：`source` 字段未正确设置**
- 如果从企查查/爱企查搜索返回的结果 `source` 字段为空或错误
- `isLocal` 可能被错误判断
- "选择"按钮不会显示（BUG）

**场景 C：UI 状态不一致**
- 用户看到复选框但没有看到"选择"按钮
- 说明 `isSelectionMode == true`，但 SelectionBar 没有显示
- 可能是状态更新问题

## 已添加的调试日志

### 1. 搜索页面日志（enterprise_search_page.dart）

```dart
if (searchState.hasResults) {
  final localCount = searchState.results.where((e) => e.isLocal).length;
  final remoteCount = searchState.results.where((e) => !e.isLocal).length;
  debugPrint('[企业搜索] 结果统计: 总计=${searchState.results.length}, 本地=$localCount, 远程=$remoteCount');
  debugPrint('[企业搜索] 选择模式: ${searchState.isSelectionMode}');
  debugPrint('[企业搜索] 是否显示"选择"按钮: ${!searchState.isSelectionMode && searchState.hasResults && searchState.results.any((e) => !e.isLocal)}');
}
```

### 2. 企查查搜索日志（enterprise_provider.dart）

```dart
if (qccResult.success) {
  // Debug: 检查返回结果的 source 字段
  for (final enterprise in qccResult.items) {
    debugPrint('[企查查搜索] 企业: ${enterprise.name}, source=${enterprise.source}, isLocal=${enterprise.isLocal}');
  }
  // ...
}
```

### 3. 搜索完成提示（enterprise_search_page.dart）

```dart
// 搜索完成后，检查是否有可选企业，如果没有则显示提示
if (mounted) {
  final newState = ref.read(enterpriseSearchProvider);
  if (newState.hasResults && !newState.results.any((e) => !e.isLocal)) {
    // 所有结果都是本地企业，显示提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('搜索结果中的企业都已在本地库中'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
```

## 测试步骤

### 1. 重新编译并安装应用

```bash
cd mobile/cordyscrm_flutter
flutter clean
flutter pub get
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

或使用提供的脚本：

```bash
chmod +x scripts/test_selection_mode_fix.sh
./scripts/test_selection_mode_fix.sh
```

### 2. 启动日志监控

在另一个终端窗口中运行：

```bash
adb logcat | grep -E '企业搜索|企查查搜索|选择模式'
```

### 3. 执行测试用例

#### 测试用例 1：搜索已存在的本地企业

1. 打开应用并登录
2. 进入企业搜索页面
3. 搜索一个已经导入到本地的企业名称
4. **预期结果**：
   - 显示搜索结果
   - 不显示"选择"按钮（因为都是本地企业）
   - 显示提示："搜索结果中的企业都已在本地库中"
   - 日志显示：`本地=X, 远程=0`

#### 测试用例 2：搜索新企业（企查查）

1. 确保已打开企查查 WebView 页面并登录
2. 在企业搜索页面搜索一个新企业（例如："腾讯"）
3. **预期结果**：
   - 显示搜索结果
   - **显示"选择"按钮**
   - 日志显示每个企业的 `source=qcc, isLocal=false`
   - 日志显示：`本地=0, 远程=X`
   - 日志显示：`是否显示"选择"按钮: true`

#### 测试用例 3：进入选择模式

1. 在测试用例 2 的基础上，点击"选择"按钮
2. **预期结果**：
   - 每个企业项显示复选框
   - **底部显示 SelectionBar**
   - SelectionBar 包含："取消"按钮、"全选" Checkbox、"批量导入"按钮
   - 日志显示：`选择模式: true`

#### 测试用例 4：批量导入

1. 在选择模式下，选择一个或多个企业
2. 点击"批量导入"按钮
3. 确认导入
4. **预期结果**：
   - 显示导入进度对话框
   - 导入完成后显示结果摘要
   - 自动退出选择模式
   - 刷新搜索结果，导入的企业标记为"已导入"

## 关键检查点

### 检查点 1：source 字段是否正确

查看日志中的输出：

```
[企查查搜索] 企业: 腾讯科技, source=qcc, isLocal=false
```

- ✅ 如果 `source=qcc` 且 `isLocal=false`，说明字段设置正确
- ❌ 如果 `source=` 为空或 `isLocal=true`，说明有 BUG

### 检查点 2：按钮显示逻辑

查看日志中的输出：

```
[企业搜索] 结果统计: 总计=10, 本地=0, 远程=10
[企业搜索] 选择模式: false
[企业搜索] 是否显示"选择"按钮: true
```

- ✅ 如果 `远程>0` 且 `是否显示"选择"按钮: true`，说明逻辑正确
- ❌ 如果 `远程>0` 但 `是否显示"选择"按钮: false`，说明有 BUG

### 检查点 3：SelectionBar 显示

进入选择模式后：

- ✅ 底部应该显示 SelectionBar
- ❌ 如果没有显示，检查 `bottomNavigationBar` 的条件

## 已知问题和解决方案

### 问题 1：所有结果都是本地企业

**症状**：搜索后不显示"选择"按钮

**原因**：搜索的企业都已经在本地数据库中

**解决方案**：
- 这是正常行为，不是 BUG
- 应用会显示提示："搜索结果中的企业都已在本地库中"
- 用户应该搜索其他未导入的企业

### 问题 2：企查查 WebView 未打开

**症状**：搜索失败，提示"请先打开企查查页面"

**原因**：WebView 控制器未初始化

**解决方案**：
- 点击右上角的"打开企查查"按钮
- 在 WebView 页面登录企查查
- 返回搜索页面重新搜索

### 问题 3：source 字段为空

**症状**：从企查查搜索返回的结果 `isLocal=true`

**原因**：repository 层未正确设置 `source` 字段

**解决方案**：
- 检查 `enterprise_repository_impl.dart` 第 244 行
- 确保创建 Enterprise 对象时设置 `source: 'qcc'`

## 代码修改总结

### 修改 1：添加搜索完成提示

**文件**：`enterprise_search_page.dart`

**目的**：当所有搜索结果都是本地企业时，提示用户

### 修改 2：添加调试日志

**文件**：
- `enterprise_search_page.dart`
- `enterprise_provider.dart`

**目的**：帮助诊断 `source` 字段和 `isLocal` 判断问题

## 下一步

如果测试后仍然有问题，请提供：

1. 完整的日志输出（包含 `[企业搜索]` 和 `[企查查搜索]` 标签）
2. 搜索的关键词
3. 是否打开了企查查 WebView 页面
4. 截图显示当前的 UI 状态

这些信息将帮助进一步诊断问题。
