# Implementation Plan: Enterprise Batch Import Feature

## Overview

本实现计划将企业批量导入功能分解为可执行的编码任务。实现顺序为：状态扩展 → 选择逻辑 → UI 组件 → 批量导入 → 测试。

## Tasks

- [x] 1. 扩展 EnterpriseSearchState 数据模型
  - 在 `enterprise_provider.dart` 中修改 `EnterpriseSearchState` 类
  - 添加 `isSelectionMode` 字段（bool，默认 false）
  - 添加 `selectedIds` 字段（Set<String>，默认空集合）
  - 添加 `isBatchImporting` 字段（bool，默认 false）
  - 添加 `importProgress` 字段（int，默认 0）
  - 添加 `importTotal` 字段（int，默认 0）
  - 添加 `importErrors` 字段（List<BatchImportError>，默认空列表）
  - 添加 getters: `selectedCount`, `hasSelection`, `canBatchImport`, `isAllSelected`, `selectedEnterprises`
  - 更新 `copyWith` 方法支持新字段
  - 创建 `BatchImportError` 数据类
  - _Requirements: 1.2, 1.3, 2.4, 3.3, 4.3_

- [x] 2. 实现选择模式管理方法
  - 在 `EnterpriseSearchNotifier` 中添加 `enterSelectionMode(String initialSelectedId)` 方法
  - 实现 `exitSelectionMode()` 方法，清除所有选择状态
  - 实现 `toggleSelection(String creditCode)` 方法
    - 检查企业是否为本地企业（isLocal），如果是则返回
    - 检查是否达到50个上限
    - 切换选择状态
  - _Requirements: 1.1, 1.4, 2.1, 2.2, 2.3, 3.1, 3.3, 5.1, 5.3_

- [x] 3. 实现全选/取消全选功能
  - 在 `EnterpriseSearchNotifier` 中添加 `toggleSelectAll()` 方法
  - 过滤出可选择的企业（非本地企业）
  - 根据当前状态执行全选或取消全选
  - 限制最多选择50个企业
  - _Requirements: 2.5, 2.6, 2.7, 3.3_

- [x] 4. 修改 EnterpriseSearchResultItem 支持选择模式
  - 在 `enterprise_search_result_item.dart` 中添加选择模式相关参数
  - 添加 `isSelectionMode`, `isSelected`, `onSelectionChanged`, `onLongPress` 参数
  - 在选择模式下显示 Checkbox
  - 本地企业显示"已导入" badge 并禁用 checkbox
  - 实现长按进入选择模式的逻辑
  - 在选择模式下，点击切换选择状态而非导航
  - _Requirements: 1.1, 1.2, 1.5, 2.1, 2.2, 3.1_

- [x] 5. 创建 SelectionBar 组件
  - 创建 `lib/presentation/features/enterprise/widgets/selection_bar.dart`
  - 显示已选数量
  - 提供"取消"按钮（退出选择模式）
  - 提供"全选/取消全选"按钮
  - 提供"批量导入"按钮（显示已选数量）
  - 使用 Material 3 设计风格
  - _Requirements: 1.3, 2.4, 2.5, 2.6, 5.1_

- [x] 6. 修改 EnterpriseSearchPage 集成选择模式
  - 监听选择状态变化
  - 在选择模式下显示 SelectionBar
  - 传递选择相关回调到 EnterpriseSearchResultItem
  - 处理返回按钮在选择模式下的行为（退出选择模式）
  - 在新搜索时自动退出选择模式
  - _Requirements: 1.3, 5.1, 5.2, 6.3_

- [x] 7. 实现批量导入逻辑
  - 在 `EnterpriseSearchNotifier` 中添加 `batchImport()` 方法
  - 循环调用 `_repository.importEnterprise()` 导入每个企业
  - 更新导入进度（importProgress）
  - 收集导入错误到 importErrors 列表
  - 每次导入间隔 300ms 避免请求过快
  - 全部成功时退出选择模式并刷新结果
  - _Requirements: 4.2, 4.3, 4.4, 4.7, 6.1_

- [x] 8. 创建批量导入确认对话框
  - 在 `EnterpriseSearchPage` 中添加确认对话框逻辑
  - 显示将要导入的企业数量
  - 提供"确认"和"取消"按钮
  - 确认后调用 `batchImport()` 方法
  - _Requirements: 4.1_

- [x] 9. 创建 BatchImportProgressDialog 组件
  - 创建 `lib/presentation/features/enterprise/widgets/batch_import_progress_dialog.dart`
  - 显示线性进度条
  - 显示当前进度文本（如 "5 / 10"）
  - 不可取消（导入过程中）
  - _Requirements: 4.3, 4.4_

- [x] 10. 创建 BatchImportSummaryDialog 组件
  - 创建 `lib/presentation/features/enterprise/widgets/batch_import_summary_dialog.dart`
  - 显示成功和失败数量
  - 列出失败的企业及错误信息
  - 提供"确定"按钮关闭对话框
  - _Requirements: 4.5, 4.6_

- [x] 11. 集成进度和结果对话框
  - 在 `EnterpriseSearchPage` 中监听批量导入状态
  - 导入开始时显示 BatchImportProgressDialog
  - 导入完成时关闭进度对话框并显示 BatchImportSummaryDialog
  - 处理导入失败的情况（保持选择模式）
  - _Requirements: 4.3, 4.4, 4.5, 4.6, 6.2_

- [x] 12. 实现 Toast 提示
  - 在 `toggleSelection` 中添加本地企业选择提示
  - 在 `toggleSelection` 中添加选择上限提示
  - 使用 ScaffoldMessenger 显示 SnackBar
  - _Requirements: 3.2, 3.4_

- [x] 13. 处理搜索和数据源切换
  - 在 `search()` 方法开始时检查并退出选择模式
  - 在数据源切换时退出选择模式
  - 确保选择状态被清除
  - _Requirements: 6.3, 6.4_

- [x] 14. Checkpoint - 功能验证
  - 已修复两个关键问题：
    1. 全选/取消全选逻辑：修改 `isAllSelected` 判断，使其在选中数量达到上限时也返回 true
    2. Toast 提示：添加 `SelectionToggleError` 枚举和 UI 层反馈机制
  - 代码已通过 Codex 审核，逻辑正确，达到生产级质量
  - Flutter analyze 通过（无新增警告）
  - _Completed: 2025-12-26, Commit: f68622c37_

- [ ]* 15. 编写属性测试
  - [ ]* 15.1 Property 1: 选择模式切换一致性测试
    - **Property 1: Selection mode toggle consistency**
    - **Validates: Requirements 1.2, 1.3, 5.3, 5.4**
  - [ ]* 15.2 Property 2: 本地企业排除测试
    - **Property 2: Local enterprise exclusion**
    - **Validates: Requirements 3.1, 3.2**
  - [ ]* 15.3 Property 3: 选择上限强制测试
    - **Property 3: Selection limit enforcement**
    - **Validates: Requirements 3.3, 3.4**
  - [ ]* 15.4 Property 4: 批量导入进度准确性测试
    - **Property 4: Batch import progress accuracy**
    - **Validates: Requirements 4.3, 4.4**
  - [ ]* 15.5 Property 5: 导入结果一致性测试
    - **Property 5: Import result consistency**
    - **Validates: Requirements 4.5, 4.6**
  - [ ]* 15.6 Property 6: 导入期间选择状态保留测试
    - **Property 6: Selection state preservation during import**
    - **Validates: Requirements 6.1, 6.2**
  - [ ]* 15.7 Property 7: 搜索时清除选择测试
    - **Property 7: Selection clearing on search**
    - **Validates: Requirements 6.3, 6.4**

- [x] 16. Final Checkpoint - 代码审核和提交
  - Codex MCP 最终审核完成：代码质量评分 8/10
  - 功能完成度：所有核心功能已实现
    - 长按进入选择模式 ✓
    - 选择/取消选择企业 ✓
    - 全选/取消全选 ✓
    - 批量导入 ✓
    - 进度显示 ✓
    - 结果摘要 ✓
    - 本地企业不可选 ✓
    - 选择上限（50个）✓
  - 已修复中等严重度问题：对话框关闭前添加路由检查
  - Flutter analyze 通过（无新增警告）
  - 代码已提交：
    - Commit 1: f68622c37 - 修复全选和Toast提示问题
    - Commit 2: 6fbbe602e - 添加对话框关闭前的路由检查
  - _Completed: 2025-12-26_

## Notes

- 任务标记 `*` 的为可选任务（属性测试），可以跳过以加快 MVP 开发
- 每个任务引用了具体的需求条款以便追溯
- Checkpoint 任务用于验证阶段性成果
- 批量导入采用顺序执行，避免并发请求导致的问题
- 每次导入间隔 300ms，防止后端限流

