# 企业搜索批量导入 UI 问题修复

## 问题描述

用户报告在企业搜索完成后，"全选"按钮和"批量导入"操作栏没有出现。

## 根本原因

"选择"按钮的显示条件要求至少有一个**非本地企业**（`isLocal == false`）：

```dart
if (!searchState.isSelectionMode &&
    searchState.hasResults &&
    searchState.results.any((e) => !e.isLocal))  // 关键条件
```

企业的 `isLocal` 由 `source` 字段决定：
- `source == 'local'` → 本地企业，不可选择
- `source == 'qcc'` 或 `'iqicha'` → 远程企业，可选择

## 可能的场景

### 场景 1：所有结果都是本地企业（正常）

如果搜索的企业都已经在本地数据库中，"选择"按钮不会显示。这是**预期行为**。

**解决方案**：搜索其他未导入的企业。

### 场景 2：source 字段未正确设置（BUG）

如果从企查查/爱企查搜索返回的结果 `source` 字段为空或错误，会导致 `isLocal` 判断错误。

**解决方案**：检查 `enterprise_repository_impl.dart` 确保正确设置 `source: 'qcc'`。

## 已实施的修复

### 1. 添加用户提示

当所有搜索结果都是本地企业时，显示提示：

```
"搜索结果中的企业都已在本地库中"
```

### 2. 添加调试日志

在搜索页面和 provider 中添加详细日志：

```
[企业搜索] 结果统计: 总计=10, 本地=0, 远程=10
[企业搜索] 选择模式: false
[企业搜索] 是否显示"选择"按钮: true
[企查查搜索] 企业: 腾讯科技, source=qcc, isLocal=false
```

### 3. 创建调试指南

详细的调试步骤和测试用例，参见 `SELECTION_MODE_DEBUG_GUIDE.md`。

## 测试步骤

1. 重新编译并安装应用：
   ```bash
   ./scripts/test_selection_mode_fix.sh
   ```

2. 启动日志监控：
   ```bash
   adb logcat | grep -E '企业搜索|企查查搜索'
   ```

3. 测试搜索功能：
   - 搜索已存在的本地企业 → 应显示提示，不显示"选择"按钮
   - 搜索新企业（企查查）→ 应显示"选择"按钮
   - 进入选择模式 → 应显示底部 SelectionBar

## 验证清单

- [ ] 搜索本地企业时显示提示信息
- [ ] 搜索远程企业时显示"选择"按钮
- [ ] 日志显示正确的 `source` 和 `isLocal` 值
- [ ] 点击"选择"按钮后显示 SelectionBar
- [ ] SelectionBar 包含"全选"和"批量导入"功能
- [ ] 批量导入功能正常工作

## 相关文件

- `enterprise_search_page.dart` - 搜索页面 UI 和逻辑
- `enterprise_provider.dart` - 搜索状态管理
- `enterprise.dart` - Enterprise 实体定义
- `enterprise_repository_impl.dart` - 搜索 API 调用
- `SELECTION_MODE_DEBUG_GUIDE.md` - 完整调试指南

## 下一步

如果问题仍然存在，请提供：
1. 完整的日志输出
2. 搜索的关键词
3. 截图显示当前 UI 状态

这将帮助进一步诊断问题。
