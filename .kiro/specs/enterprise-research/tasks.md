# Implementation Plan: Enterprise Re-Search Feature

## Overview

本实现计划将"重新搜索"功能分解为可执行的编码任务。实现顺序为：状态扩展 → Provider 方法 → UI 组件 → 测试。

## Tasks

- [x] 1. 扩展 EnterpriseSearchState 数据模型
  - 在 `enterprise_provider.dart` 中修改 `EnterpriseSearchState` 类
  - 添加 `isReSearching` 字段（bool，默认 false）
  - 添加 `reSearchError` 字段（String?，默认 null）
  - 添加 `hasReSearchError` getter
  - 添加 `canReSearch` getter（判断是否可以执行重新搜索）
  - 更新 `copyWith` 方法支持新字段
  - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 2. 实现 reSearchExternal 方法
  - 在 `EnterpriseSearchNotifier` 中添加 `reSearchExternal()` 方法
  - 检查 `canReSearch` 状态
  - 保留当前本地结果
  - 根据当前数据源类型调用 `searchQichacha` 或 `searchAiqicha`
  - 成功时追加外部结果到本地结果之后
  - 更新 `dataSource` 为 `mixed`
  - 失败时设置 `reSearchError`，保留本地结果
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 4.1, 4.2_

- [x] 3. 更新 dataSourceLabel 支持混合结果
  - 修改 `EnterpriseSearchState` 的 `dataSourceLabel` getter
  - 当 `dataSource` 为 `mixed` 时，根据外部数据源类型返回 "本地 + 企查查" 或 "本地 + 爱企查"
  - 需要访问 `enterpriseDataSourceTypeProvider` 获取当前外部数据源类型
  - _Requirements: 3.2_

- [x] 4. 修改数据来源横幅 UI
  - 在 `enterprise_search_page.dart` 中修改 `_buildDataSourceBanner` 方法
  - 当 `state.canReSearch` 为 true 时，在横幅右侧显示"重新搜索"按钮
  - 按钮文字显示当前外部数据源名称（如"搜索企查查"）
  - 按钮点击调用 `ref.read(enterpriseSearchProvider.notifier).reSearchExternal()`
  - _Requirements: 1.1, 2.1_

- [x] 5. 实现重新搜索加载状态 UI
  - 当 `state.isReSearching` 为 true 时，按钮显示加载指示器
  - 按钮文字变为"搜索中..."
  - 禁用按钮点击
  - _Requirements: 2.2_

- [x] 6. 实现重新搜索错误提示
  - 监听 `state.reSearchError` 变化
  - 当有错误时，通过 SnackBar 显示错误信息
  - 错误不影响已有的本地结果展示
  - _Requirements: 2.5_

- [x] 7. 更新 clear 方法
  - 确保 `clear()` 方法重置所有新增字段
  - `isReSearching` 重置为 false
  - `reSearchError` 重置为 null
  - _Requirements: 4.3_

- [x] 8. Checkpoint - 功能验证
  - 确保所有代码编译通过
  - 在真机上测试完整流程：
    1. 搜索一个本地存在的企业名称
    2. 确认显示"重新搜索"按钮
    3. 点击按钮，确认加载状态
    4. 确认外部结果追加到本地结果之后
    5. 确认横幅显示"本地 + 企查查"
  - 如有问题，请告知用户

- [x] 9. 实现结果去重逻辑 ✅
  - 在 `reSearchExternal` 方法中，合并结果前，根据 `creditCode` 移除与本地结果重复的外部结果
  - 使用 `Set<String>` 存储本地结果的 `creditCode` 以提升查找效率
  - 保留本地版本的记录，丢弃外部重复记录
  - 空 creditCode 不参与去重，避免误删
  - _Requirements: 3.4_
  - _Completed: 2025-12-26, Commit: 1d3ce8fba_

- [ ] 10. 实现"未找到新结果"的 UI 反馈 ✅
  - 当 `reSearchExternal` 成功但去重后的外部结果为空时，触发一个 SnackBar 通知
  - 提示文案：`"已从[数据源名称]搜索，未发现新结果。"`
  - 这属于成功场景，不应触发 `reSearchError`
  - 添加 `reSearchNotice` 字段和相应的清理逻辑
  - 使用中性色背景和合适的文本色
  - _Requirements: 2.6_
  - _Completed: 2025-12-26, Commit: 0ef386539_

- [x] 11. 重构错误处理为结构化错误 ✅
  - 定义 `ReSearchError` 类和 `ReSearchErrorType` 枚举
  - 修改 `EnterpriseSearchState` 的 `reSearchError` 字段类型从 `String?` 改为 `ReSearchError?`
  - 在 `reSearchExternal` 方法中根据错误消息分类错误类型
  - 在 UI 层根据错误类型显示不同的 SnackBar 消息和操作建议
  - _Requirements: 5.1, 5.2, 5.3_
  - _Completed: 2025-12-26, Commit: [pending]_

- [ ] 12. 编写属性测试（高优先级）
  - [ ] 12.1 Property 5: 错误处理保留本地结果测试
    - **Property 5: Error handling preserves local results**
    - **Validates: Requirements 2.5, 4.2**
    - 使用 `glados` 库生成随机失败场景，验证本地结果不变
  - [ ] 12.2 Property 3: 结果排序与合并测试
    - **Property 3: Result ordering and merging after re-search**
    - **Validates: Requirements 2.3, 3.1, 3.4, 4.1**
    - 验证本地结果在前、去重后的外部结果在后
  - [ ] 12.3 Property 6: 清除操作状态重置测试
    - **Property 6: Clear action clears all results**
    - **Validates: Requirements 4.3**
    - 验证 `clear()` 方法正确重置所有状态

- [ ] 13. Final Checkpoint - 代码审核和提交
  - 使用 Codex MCP 审核代码改动
  - 运行 `flutter analyze` 确保无警告
  - 提交代码：`git commit -m "feat(flutter): 企业搜索重新搜索功能完善（去重+结构化错误+属性测试）"`

## Notes

- 任务标记 `*` 的为可选任务（属性测试），可以跳过以加快 MVP 开发
- 每个任务引用了具体的需求条款以便追溯
- Checkpoint 任务用于验证阶段性成果
