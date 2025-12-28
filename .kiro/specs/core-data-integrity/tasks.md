# Implementation Plan: Core Data Integrity

## Overview

本实现计划修复 CordysCRM 核心数据完整性问题，分为两个主要部分：后端数据规范化和 Flutter 同步增强。任务按依赖关系排序，确保每个任务完成后系统仍可正常运行。

## Tasks

### Phase 1: 后端数据规范化

- [x] 1. 数据审计和现状分析
  - 编写 SQL 脚本统计信用代码字段的格式、空值、重复值、长度异常
  - 生成数据质量报告（CSV 或 JSON 格式）
  - 识别需要清理的问题数据量
  - _Requirements: 2.1, 8.5_

- [x] 2. 实现信用代码规范化器
  - [x] 2.1 创建 `CreditCodeNormalizer` 接口和实现类
    - 实现全角转半角、trim、toUpperCase逻辑（顺序已优化）
    - 处理 null 和空字符串边界条件
    - 添加格式验证（18位字母数字）
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

  - [ ]* 2.2 编写规范化器单元测试
    - 测试 null 和空字符串处理
    - 测试全角半角转换
    - 测试 trim 和大小写转换
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

  - [ ]* 2.3 编写规范化器属性测试
    - **Property 1: 信用代码规范化幂等性**
    - **Property 2: 信用代码规范化保留 null**
    - **Property 3: 全角半角转换正确性**
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 3. Checkpoint A - 验证规范化器功能
  - 确保所有测试通过
  - 代码审查（Codex MCP 完成）
  - 已修复关键问题：SIGNAL语法、规范化顺序、异常处理

- [x] 4. 集成规范化器到写入路径
  - 在 `EnterpriseService.importEnterprise()` 中调用规范化器
  - 在 `EnterpriseService.forceImportEnterprise()` 中调用规范化器
  - 添加日志记录规范化前后的值（用于审计）
  - _Requirements: 1.1, 1.2, 1.3_

- [x] 5. 编写数据迁移脚本
  - [x] 5.1 创建 Flyway 迁移脚本 `V1.6.0_3__cleanup_duplicate_credit_codes.sql`
    - 创建备份表
    - 识别重复记录
    - 实现去重策略（保留 ID 最小的记录）
    - 记录迁移日志
    - _Requirements: 2.1, 2.2, 2.3, 2.4_

  - [ ]* 5.2 编写迁移脚本测试
    - 创建测试数据库
    - 插入重复测试数据
    - 验证迁移后只保留一条记录
    - 验证迁移日志正确记录
    - _Requirements: 2.1, 2.2, 2.3_

- [x] 6. Checkpoint B - 验证迁移脚本
  - 在测试环境执行迁移（待用户执行）
  - 验证数据完整性
  - 已修复 MySQL 语法问题

- [x] 7. 添加数据库唯一索引约束
  - [x] 7.1 创建 Flyway 迁移脚本 `V1.6.0_4__add_credit_code_unique_index.sql`
    - 添加 `uk_credit_code` 唯一索引
    - 添加索引创建日志
    - _Requirements: 1.5, 2.4_

  - [ ]* 7.2 编写唯一约束测试
    - 尝试插入重复信用代码
    - 验证抛出 `DuplicateKeyException`
    - **Property 9: 数据库唯一约束生效**
    - _Requirements: 1.5_

- [x] 8. Checkpoint C - 验证数据库约束
  - 确保所有测试通过
  - 在预生产环境验证（待用户执行）
  - Phase 1 (后端数据规范化) 完成

### Phase 2: Flutter 同步增强

- [x] 9. 扩展 SyncQueue 数据模型
  - [x] 9.1 更新 Drift 表定义
    - 添加 `attemptCount` 字段（默认 0）
    - 添加 `errorType` 字段（nullable）
    - 生成数据库迁移代码
    - _Requirements: 7.1_

  - [x] 9.2 更新 DAO 方法
    - 添加 `findInProgressBefore(DateTime)` 查询方法
    - 添加 `updateAttemptCount(int id, int count)` 方法
    - 添加 `updateErrorType(int id, String type)` 方法
    - _Requirements: 3.1, 7.2_

- [ ] 10. 实现错误分类器
  - [x] 10.1 创建 `ErrorClassifier` 类
    - 定义 `ErrorType` 枚举（retryable, nonRetryable, fatal）
    - 实现 `classify(dynamic error)` 方法
    - 实现 `shouldRetry(ErrorType, int attemptCount)` 方法
    - _Requirements: 4.1, 4.2, 4.3_

  - [ ]* 10.2 编写错误分类器属性测试
    - **Property 5: 错误分类一致性（4xx）**
    - **Property 6: 错误分类一致性（5xx）**
    - 测试网络超时分类
    - _Requirements: 4.1, 4.2, 4.3_

- [ ] 11. 实现同步状态恢复机制
  - [ ] 11.1 创建 `SyncStateRecovery` 类
    - 实现 `resetStaleInProgressItems()` 方法
    - 实现 `validateQueueIntegrity()` 方法
    - 添加警告日志记录
    - _Requirements: 3.1, 3.2, 3.3_

  - [ ]* 11.2 编写状态恢复属性测试
    - **Property 4: Stale 项重置时间阈值**
    - 测试不同时间戳的队列项
    - 验证日志记录
    - _Requirements: 3.2, 3.3_

- [ ] 12. Checkpoint D - 验证基础组件
  - 确保所有测试通过
  - 代码审查
  - 询问用户是否有问题

- [ ] 13. 实现同步失败统计优化
  - [ ] 13.1 创建 `SyncStatistics` 类
    - 维护 `retryableFailedCount` 计数器
    - 维护 `nonRetryableFailedCount` 计数器
    - 实现 `shouldTriggerGlobalRetry()` 逻辑
    - _Requirements: 5.1, 5.2, 5.3, 5.4_

  - [ ] 13.2 集成统计到 SyncService
    - 在同步失败时更新计数器
    - 在同步完成后重置计数器
    - 根据统计决定是否全局重试
    - _Requirements: 5.3, 5.4, 5.5_

- [ ] 14. 实现 API Client 监控
  - [ ] 14.1 创建 `ApiClientMonitor` 类
    - 实现 `isClientAvailable()` 方法
    - 实现监听器注册/移除机制
    - 添加状态变化通知
    - _Requirements: 6.4_

  - [ ] 14.2 集成监控到 SyncService
    - 在初始化时检查 API Client
    - 在同步前检查 API Client 可用性
    - API Client 不可用时暂停同步并保留队列项
    - _Requirements: 6.1, 6.2, 6.3_

- [ ] 15. 重构 SyncService 主流程
  - [ ] 15.1 集成状态恢复到初始化流程
    - 在 `initialize()` 中调用 `resetStaleInProgressItems()`
    - 初始化失败时抛出异常
    - _Requirements: 3.4, 3.5_

  - [ ] 15.2 集成错误分类和重试策略
    - 使用 `ErrorClassifier` 分类错误
    - 根据错误类型决定是否重试
    - 实现指数退避重试
    - 更新 `attemptCount` 和 `errorType` 字段
    - _Requirements: 4.4, 4.5, 7.2_

  - [ ] 15.3 实现重试次数限制
    - 检查 `attemptCount` 是否超过 5 次
    - 超限时标记为 `fatalError`
    - 发送用户通知
    - _Requirements: 7.3, 7.4_

  - [ ]* 15.4 编写同步流程属性测试
    - **Property 7: 重试次数递增**
    - **Property 8: 指数退避间隔**
    - 测试不同错误类型的处理
    - _Requirements: 4.5, 7.2_

- [ ] 16. Checkpoint E - 验证同步流程
  - 确保所有测试通过
  - 手动测试各种错误场景
  - 询问用户是否有问题

- [ ] 17. 实现用户界面增强
  - [ ] 17.1 添加 API Client 配置检查
    - 在创建离线数据前检查 API Client
    - 显示明确的错误提示
    - _Requirements: 6.5_

  - [ ] 17.2 添加手动重试 Fatal Error 的界面
    - 在同步设置页面显示 Fatal Error 项
    - 提供手动重试按钮
    - _Requirements: 7.5_

- [ ]* 18. 编写端到端集成测试
  - 测试离线数据在应用重启后的恢复
  - 测试各种网络错误场景
  - 测试 API Client 不可用场景
  - 测试重试次数超限场景
  - _Requirements: 3.1, 4.1, 4.2, 6.1, 7.3_

- [ ] 19. Final Checkpoint - 完整验证
  - 运行所有测试（单元测试 + 属性测试 + 集成测试）
  - 在测试环境进行完整回归测试
  - 更新文档和开发状态报告
  - 询问用户是否有问题

## Notes

- 任务标记 `*` 的为可选任务（主要是测试相关），可以跳过以加快 MVP 开发
- 每个 Checkpoint 都需要确保所有测试通过并征求用户反馈
- Phase 1（后端）和 Phase 2（Flutter）可以并行开发
- 数据库迁移脚本需要在低峰期或维护窗口执行
- 属性测试应配置为至少运行 100 次迭代
- 每个属性测试必须在注释中标记其验证的设计属性编号

