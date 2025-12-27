# Requirements Document: Core Data Integrity

## Introduction

本规格文档旨在修复 CordysCRM 系统中识别出的核心数据完整性问题，包括后端企业数据去重规范化和 Flutter 离线同步状态管理缺陷。这些问题属于 P0 级别，直接影响数据一致性和系统可靠性。

## Glossary

- **System**: CordysCRM 系统
- **Backend**: Spring Boot 后端服务
- **Flutter_App**: Flutter 移动应用
- **SyncService**: Flutter 离线同步服务
- **EnterpriseService**: 后端企业信息服务
- **Credit_Code**: 统一社会信用代码（18位）
- **SyncQueue**: 离线同步队列
- **InProgress_State**: 同步队列中的"进行中"状态
- **Pending_State**: 同步队列中的"待处理"状态
- **Failed_State**: 同步队列中的"失败"状态
- **Stale_Item**: 长时间处于 InProgress 状态的队列项
- **Retryable_Error**: 可重试的错误（如网络超时）
- **Non_Retryable_Error**: 不可重试的错误（如 4xx 客户端错误）

## Requirements

### Requirement 1: 企业信用代码规范化

**User Story:** 作为系统管理员，我希望企业信用代码在存储前被标准化，以避免因格式差异导致的重复导入。

#### Acceptance Criteria

1. WHEN 企业信息导入时，THE System SHALL 对 Credit_Code 进行 trim 操作移除首尾空白
2. WHEN 企业信息导入时，THE System SHALL 将 Credit_Code 转换为大写
3. WHEN 企业信息导入时，THE System SHALL 将全角字符转换为半角字符
4. WHEN Credit_Code 为 null 或空字符串时，THE System SHALL 保持为 null
5. THE Backend SHALL 在数据库层添加 Credit_Code 唯一索引约束

### Requirement 2: 历史数据清理

**User Story:** 作为数据库管理员，我希望清理现有的重复企业数据，以确保数据库约束能够成功添加。

#### Acceptance Criteria

1. WHEN 执行数据迁移时，THE System SHALL 识别所有重复的 Credit_Code 记录
2. WHEN 发现重复记录时，THE System SHALL 保留 ID 最小的记录
3. WHEN 删除重复记录时，THE System SHALL 记录删除操作到迁移日志
4. WHEN 清理完成后，THE System SHALL 添加 Credit_Code 唯一索引
5. THE System SHALL 提供回滚机制以防迁移失败

### Requirement 3: 同步状态自愈机制

**User Story:** 作为移动应用用户，我希望即使应用崩溃，我的离线数据也能在下次启动时继续同步，而不会永久丢失。

#### Acceptance Criteria

1. WHEN Flutter_App 启动时，THE SyncService SHALL 检查所有 InProgress_State 的队列项
2. WHEN InProgress_State 项的更新时间超过 5 分钟时，THE SyncService SHALL 将其重置为 Pending_State
3. WHEN 重置 Stale_Item 时，THE SyncService SHALL 记录警告日志
4. THE SyncService SHALL 在初始化完成后才开始正常同步流程
5. WHEN 重置操作失败时，THE SyncService SHALL 抛出初始化异常

### Requirement 4: 错误分类与重试策略

**User Story:** 作为移动应用用户，我希望系统能够智能区分可重试和不可重试的错误，避免无意义的重试消耗电量和流量。

#### Acceptance Criteria

1. WHEN 同步遇到 4xx 客户端错误时，THE SyncService SHALL 标记为 Non_Retryable_Error
2. WHEN 同步遇到 5xx 服务器错误时，THE SyncService SHALL 标记为 Retryable_Error
3. WHEN 同步遇到网络超时时，THE SyncService SHALL 标记为 Retryable_Error
4. WHEN 遇到 Non_Retryable_Error 时，THE SyncService SHALL 将队列项标记为 Failed_State 且不再重试
5. WHEN 遇到 Retryable_Error 时，THE SyncService SHALL 使用指数退避策略重试

### Requirement 5: 同步失败统计优化

**User Story:** 作为开发者，我希望同步失败统计能够区分可重试和不可重试的错误，以便更准确地判断是否需要全局重试。

#### Acceptance Criteria

1. THE SyncService SHALL 维护 retryable_failed_count 计数器
2. THE SyncService SHALL 维护 non_retryable_failed_count 计数器
3. WHEN 所有失败都是 Non_Retryable_Error 时，THE SyncService SHALL 不触发全局重试
4. WHEN 存在 Retryable_Error 时，THE SyncService SHALL 触发全局重试
5. THE SyncService SHALL 在同步完成后重置失败计数器

### Requirement 6: API Client 缺失处理

**User Story:** 作为移动应用用户，我希望在未配置 API 服务器时，系统能够明确提示错误，而不是静默丢弃我的离线数据。

#### Acceptance Criteria

1. WHEN SyncService 初始化时 API Client 为 null，THE System SHALL 抛出配置错误异常
2. WHEN 同步过程中 API Client 变为 null，THE SyncService SHALL 暂停同步并保留队列项
3. WHEN API Client 恢复可用时，THE SyncService SHALL 自动恢复同步
4. THE SyncService SHALL 提供 API Client 状态监听机制
5. WHEN 用户尝试创建离线数据但 API Client 不可用时，THE System SHALL 显示明确的错误提示

### Requirement 7: 同步重试次数限制

**User Story:** 作为移动应用用户，我希望系统不会无限重试失败的同步任务，避免耗尽电量和流量。

#### Acceptance Criteria

1. THE SyncQueue SHALL 为每个队列项维护 attempt_count 字段
2. WHEN 队列项重试时，THE System SHALL 递增 attempt_count
3. WHEN attempt_count 超过 5 次时，THE System SHALL 将队列项标记为 Fatal_Error
4. WHEN 队列项标记为 Fatal_Error 时，THE System SHALL 不再自动重试
5. THE System SHALL 提供手动重试 Fatal_Error 项的接口

### Requirement 8: 数据迁移安全性

**User Story:** 作为数据库管理员，我希望数据迁移过程是安全的，能够在出现问题时回滚。

#### Acceptance Criteria

1. THE System SHALL 在迁移前创建数据库备份
2. WHEN 迁移失败时，THE System SHALL 自动回滚所有更改
3. THE System SHALL 记录详细的迁移日志
4. THE System SHALL 在迁移完成后验证数据完整性
5. THE System SHALL 提供迁移前的数据统计报告

