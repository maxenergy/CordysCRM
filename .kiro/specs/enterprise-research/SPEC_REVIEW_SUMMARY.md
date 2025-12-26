# Enterprise Re-Search Feature - Spec Review Summary

## Review Date
2024-12-26

## Review Conducted By
Kiro AI Assistant with Gemini MCP collaboration

## Executive Summary

对企业搜索"重新搜索"功能的规格文档进行了全面审查，识别出 5 个关键改进点并完成了文档更新。主要改进包括：结果去重逻辑、结构化错误处理、"未找到新结果"的 UI 反馈、以及将属性测试从可选改为必需。

## Key Findings

### 1. 缺失的去重逻辑 ⚠️ HIGH PRIORITY

**问题：** 当本地结果和外部结果包含相同企业时（基于 `creditCode`），会出现重复显示。

**影响：** 用户体验差，列表中出现重复项。

**解决方案：**
- 在合并结果前，使用 `Set<String>` 存储本地结果的 `creditCode`
- 过滤外部结果，移除与本地重复的记录
- 保留本地版本（因为本地数据是用户已验证的，具有更高业务价值）

**文档更新：**
- `requirements.md`: 新增 AC 3.4
- `design.md`: 更新 `reSearchExternal` 方法，添加去重逻辑
- `tasks.md`: 新增 Task 9

### 2. 属性测试应为必需 ⚠️ HIGH PRIORITY

**问题：** Task 9 的属性测试被标记为可选（`[ ]*`），但设计文档中定义了 6 个 Correctness Properties。

**影响：** 核心正确性保证缺失，可能导致数据丢失等严重 Bug。

**解决方案：**
- 将属性测试改为必需任务
- 优先实现 3 个最关键的属性：
  1. Property 5: 错误处理保留本地结果（最高优先级）
  2. Property 3: 结果排序与合并（高优先级）
  3. Property 6: 清除操作状态重置（中等优先级）
- 推荐使用 `glados` 库（语法更现代、可读性更好）

**文档更新：**
- `tasks.md`: 将 Task 9 改为 Task 12，标记为必需，明确优先级
- `design.md`: 更新测试策略章节，详细说明每个属性的验证方法和重要性

### 3. 缺失的"未找到新结果"反馈 ⚠️ MEDIUM PRIORITY

**问题：** 当重新搜索成功但外部结果为空（或去重后为空）时，用户没有明确反馈。

**影响：** 用户不确定操作是否成功执行。

**解决方案：**
- 使用 SnackBar 显示临时通知
- 提示文案：`"已从[数据源名称]搜索，未发现新结果。"`
- 这属于成功场景，不应触发 `reSearchError`

**文档更新：**
- `requirements.md`: 新增 AC 2.6
- `tasks.md`: 新增 Task 10

### 4. 简单字符串错误处理不够灵活 ⚠️ MEDIUM PRIORITY

**问题：** 使用 `String? reSearchError` 无法区分错误类型，UI 层无法提供针对性的操作建议。

**影响：** 用户体验差，不知道如何解决问题。

**解决方案：**
- 定义 `ReSearchErrorType` 枚举（webViewNotReady、authenticationRequired、networkOrTimeout、unknown）
- 创建 `ReSearchError` 类，包含类型和原始消息
- 在 UI 层根据错误类型显示不同的 SnackBar 和操作按钮（如"去处理"）

**文档更新：**
- `requirements.md`: 新增 Requirement 5（细化错误处理）
- `design.md`: 更新数据模型和错误处理章节
- `tasks.md`: 新增 Task 11

### 5. 设计文档与实现代码不一致 ⚠️ LOW PRIORITY

**问题：** `design.md` 中的 `reSearchExternal` 方法签名缺少 `keyword` 参数，但实际代码已实现。

**影响：** 文档不准确，可能误导后续维护。

**解决方案：**
- 更新 `design.md` 中的方法签名为 `Future<void> reSearchExternal({String? keyword})`
- 添加参数说明：解决输入框与 state.keyword 不同步的问题

**文档更新：**
- `design.md`: 更新 `EnterpriseSearchNotifier` 章节

## Updated Requirements

### New Acceptance Criteria

**Requirement 2 (Re-Search Execution):**
- AC 2.6: 未找到新结果时显示通知

**Requirement 3 (Mixed Results Display):**
- AC 3.4: 合并结果时去重，保留本地版本

**Requirement 5 (Granular Error Handling) - NEW:**
- AC 5.1: 需要登录时提供导航快捷方式
- AC 5.2: 网络问题时显示对应错误消息
- AC 5.3: 搜索引擎未就绪时指导用户初始化

## Updated Tasks

### New Tasks

- **Task 9**: 实现结果去重逻辑
- **Task 10**: 实现"未找到新结果"的 UI 反馈
- **Task 11**: 重构错误处理为结构化错误
- **Task 12**: 编写属性测试（高优先级，必需）
  - 12.1: Property 5 - 错误处理保留本地结果
  - 12.2: Property 3 - 结果排序与合并
  - 12.3: Property 6 - 清除操作状态重置
- **Task 13**: Final Checkpoint

### Task Status

- Tasks 1-8: ✅ 已完成
- Task 10 (原): ✅ 已完成（代码审核和提交）
- Tasks 9-13 (新): ⏳ 待实现

## Design Changes

### Data Model Updates

```dart
// 新增：结构化错误
enum ReSearchErrorType {
  webViewNotReady,
  authenticationRequired,
  networkOrTimeout,
  unknown,
}

class ReSearchError {
  final ReSearchErrorType type;
  final String message;
  
  String getUserMessage() { ... }
  bool get canNavigateToWebView { ... }
}

// 修改：EnterpriseSearchState
class EnterpriseSearchState {
  // 从 String? reSearchError 改为 ReSearchError? reSearchError
  final ReSearchError? reSearchError;
}
```

### Logic Updates

```dart
// reSearchExternal 方法更新
Future<void> reSearchExternal({String? keyword}) async {
  // 1. 去重逻辑
  final localCreditCodes = localResults.map((e) => e.creditCode).toSet();
  final uniqueExternalResults = externalResult.items.where(
    (ext) => !localCreditCodes.contains(ext.creditCode)
  ).toList();
  
  // 2. 未找到新结果通知
  if (uniqueExternalResults.isEmpty) {
    _notifyNoNewResults();
  }
  
  // 3. 结构化错误
  final errorType = _classifyError(externalResult.message);
  state = state.copyWith(
    reSearchError: ReSearchError(type: errorType, message: ...),
  );
}
```

## Testing Strategy Updates

### Property Tests Priority

1. **Property 5** (最高优先级): 错误处理保留本地结果
   - 防止数据丢失
   
2. **Property 3** (高优先级): 结果排序与合并
   - 验证核心功能逻辑
   
3. **Property 6** (中等优先级): 清除操作状态重置
   - 保证系统健壮性

### Recommended Tool

使用 `glados` 库进行属性测试（语法现代、可读性好、与 flutter_test 集成良好）。

## Implementation Recommendations

### Phase 1: Core Improvements (Tasks 9-11)

1. **Task 9 - 去重逻辑** (2-3 hours)
   - 修改 `reSearchExternal` 方法
   - 添加单元测试验证去重正确性

2. **Task 10 - UI 反馈** (1-2 hours)
   - 添加状态标志位或使用现有状态判断
   - 在 UI 层监听状态变化显示 SnackBar

3. **Task 11 - 结构化错误** (3-4 hours)
   - 定义错误类型和类
   - 修改 Provider 和 State
   - 更新 UI 层错误处理

### Phase 2: Quality Assurance (Task 12)

4. **Task 12 - 属性测试** (4-6 hours)
   - 安装 `glados` 依赖
   - 实现 3 个关键属性测试
   - 集成到 CI/CD 流程

### Phase 3: Final Review (Task 13)

5. **Task 13 - Checkpoint** (1-2 hours)
   - Codex MCP 代码审核
   - Flutter analyze 验证
   - Git 提交

**总估时：** 11-17 hours

## Risk Assessment

### High Risk Items

1. **去重逻辑错误** - 可能导致数据丢失或重复
   - 缓解措施：充分的单元测试和属性测试

2. **状态管理复杂度增加** - 结构化错误增加了状态复杂度
   - 缓解措施：清晰的文档和代码注释

### Medium Risk Items

1. **UI 反馈时机** - 需要准确判断"未找到新结果"的场景
   - 缓解措施：明确的条件判断逻辑

2. **错误分类准确性** - 错误消息可能不规范
   - 缓解措施：使用关键词匹配 + 默认 unknown 类型

## Conclusion

本次规格审查识别出了 5 个关键改进点，其中 2 个为高优先级（去重逻辑、属性测试）。所有改进点都已在文档中明确定义，并分解为可执行的任务。

建议按照 Phase 1 → Phase 2 → Phase 3 的顺序实施，预计总工作量为 11-17 小时。实施完成后，该功能将具备更好的用户体验、更强的健壮性和更高的代码质量。

## Next Steps

1. ✅ 完成规格文档更新（已完成）
2. ⏳ 实施 Task 9-11（核心改进）
3. ⏳ 实施 Task 12（属性测试）
4. ⏳ 实施 Task 13（最终审核）

## References

- Requirements: `.kiro/specs/enterprise-research/requirements.md`
- Design: `.kiro/specs/enterprise-research/design.md`
- Tasks: `.kiro/specs/enterprise-research/tasks.md`
- Gemini MCP Session: `eb6e933e-91c7-49b5-9acd-2649a81a400a`
