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

- [ ]* 9. 编写属性测试
  - [ ]* 9.1 Property 1: canReSearch 逻辑测试
    - **Property 1: Re-search button visibility depends on data source**
    - **Validates: Requirements 1.1, 1.2, 1.3, 1.4**
  - [ ]* 9.2 Property 3: 结果排序测试
    - **Property 3: Result ordering after re-search**
    - **Validates: Requirements 2.3, 3.1, 4.1**
  - [ ]* 9.3 Property 5: 错误处理保留本地结果测试
    - **Property 5: Error handling preserves local results**
    - **Validates: Requirements 2.5, 4.2**

- [x] 10. Final Checkpoint - 代码审核和提交
  - 使用 Codex MCP 审核代码改动
  - 运行 `flutter analyze` 确保无警告
  - 提交代码：`git commit -m "feat(flutter): 企业搜索添加重新搜索功能"`

## Notes

- 任务标记 `*` 的为可选任务（属性测试），可以跳过以加快 MVP 开发
- 每个任务引用了具体的需求条款以便追溯
- Checkpoint 任务用于验证阶段性成果
