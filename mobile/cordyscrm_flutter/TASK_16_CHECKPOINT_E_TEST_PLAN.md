# Task 16: Checkpoint E - 同步流程验证测试计划

## 概述

本文档描述 Task 16 (Checkpoint E) 的测试方案，包括自动化测试和手动测试两部分。

## 测试环境准备

### 1. 数据库准备
```bash
# 确保数据库迁移已执行
cd mobile/cordyscrm_flutter
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### 2. 后端服务准备
```bash
# 启动后端服务
cd backend
mvn spring-boot:run
```

### 3. Flutter 应用准备
```bash
# 启动 Flutter 应用（桌面版便于调试）
cd mobile/cordyscrm_flutter
flutter run -d linux
```

---

## 自动化测试部分

### Test 16.1: API Client 不可用场景测试

**测试文件**: `test/integration/sync_offline_test.dart`

**测试步骤**:
1. 初始化 SyncService，ApiClientMonitor 设置为 null
2. 尝试创建客户数据
3. 验证数据被加入 SyncQueue（status = pending）
4. 设置 ApiClientMonitor 为可用状态
5. 触发同步
6. 验证队列项被成功同步并删除

**预期结果**:
- 离线数据被正确加入队列
- Client 恢复后自动触发同步
- 同步成功后队列项被删除

---

### Test 16.2: 错误分类和重试测试

**测试文件**: `test/integration/sync_error_classification_test.dart`

**测试步骤**:

#### 16.2.1: 可重试错误（网络超时）
1. Mock SyncApiClient 抛出 DioException (connectionTimeout)
2. 创建同步项并触发同步
3. 验证错误被分类为 ErrorType.retryable
4. 验证 attemptCount 递增
5. 验证队列项状态为 failed（而非 fatalError）

#### 16.2.2: 不可重试错误（4xx）
1. Mock SyncApiClient 抛出 DioException (statusCode: 400)
2. 创建同步项并触发同步
3. 验证错误被分类为 ErrorType.nonRetryable
4. 验证 attemptCount 被设置为 maxRetryAttempts（5）
5. 验证 errorType 字段为 'nonRetryable'

#### 16.2.3: 指数退避验证
1. 创建 attemptCount = 1 的失败项
2. 验证下次重试时间约为 2^1 = 2 秒后
3. 创建 attemptCount = 3 的失败项
4. 验证下次重试时间约为 2^3 = 8 秒后

**预期结果**:
- 网络错误被正确分类为可重试
- 4xx 错误被正确分类为不可重试
- 重试间隔符合指数退避策略（允许 ±20% 误差）

---

### Test 16.3: 重试次数限制测试

**测试文件**: `test/integration/sync_retry_limit_test.dart`

**测试步骤**:
1. Mock SyncApiClient 持续抛出可重试错误（5xx）
2. 创建同步项并触发同步
3. 等待 5 次重试完成
4. 验证第 5 次失败后：
   - attemptCount = 5
   - errorType = 'fatal'
   - 队列项不再被自动重试
5. 验证 notificationStream 收到用户通知

**预期结果**:
- 达到 5 次重试后标记为 Fatal
- 用户收到通知
- 队列项保留但不再自动重试

---

## 手动测试部分

### Test 16.4: 状态恢复测试（应用崩溃模拟）

**为什么需要手动测试？**
- 需要模拟应用进程被强制终止（kill -9）
- 自动化测试难以模拟真实的崩溃场景
- 需要验证数据库持久化和恢复机制

**测试步骤**:

#### 准备阶段
1. 启动 Flutter 应用
2. 登录系统
3. 创建一个客户数据（触发同步）

#### 模拟崩溃
4. 在同步进行中（status = inProgress）时，强制终止应用：
   ```bash
   # 查找 Flutter 进程
   ps aux | grep flutter
   
   # 强制终止（使用实际 PID）
   kill -9 <PID>
   ```

#### 验证恢复
5. 重新启动应用
6. 检查日志，验证 SyncStateRecovery 被调用
7. 验证日志中显示：
   ```
   发现 X 个过期的处理中同步项，正在重置为待处理状态...
   重置过期同步项: ID=xxx, entity=customers/xxx, ...
   成功重置了 X 个过期的同步项
   ```
8. 等待自动同步触发
9. 验证数据成功同步到服务器

#### 数据库验证
10. 使用数据库工具查询 sync_queue 表：
    ```sql
    SELECT * FROM sync_queue 
    WHERE status = 'inProgress' 
    AND updated_at < datetime('now', '-5 minutes');
    ```
    应该返回 0 条记录

**预期结果**:
- 应用重启后自动检测到 stale 的 inProgress 项
- 这些项被重置为 pending 状态
- 同步自动恢复并成功完成
- 数据不丢失

---

## 验证清单

完成所有测试后，确认以下检查点：

### 功能验证
- [ ] API Client 不可用时，离线数据被正确加入队列
- [ ] API Client 恢复后，自动触发同步
- [ ] 网络错误被分类为可重试
- [ ] 4xx 错误被分类为不可重试
- [ ] 重试次数正确递增
- [ ] 指数退避间隔符合预期（2^n 秒，±20%）
- [ ] 达到 5 次重试后标记为 Fatal
- [ ] Fatal 错误触发用户通知
- [ ] 应用崩溃后，InProgress 项被重置
- [ ] 状态恢复后，同步自动继续

### 日志验证
- [ ] 错误分类日志清晰可读
- [ ] 重试日志包含尝试次数和等待时间
- [ ] 状态恢复日志包含重置项的详细信息
- [ ] Fatal 错误日志包含完整错误信息

### 数据完整性验证
- [ ] 所有测试场景下，数据不丢失
- [ ] 队列项状态转换正确
- [ ] attemptCount 和 errorType 字段正确更新
- [ ] 数据库约束正常工作（无重复项）

---

## 测试执行记录

### 自动化测试结果

**执行命令**:
```bash
flutter test test/integration/sync_offline_test.dart
flutter test test/integration/sync_error_classification_test.dart
flutter test test/integration/sync_retry_limit_test.dart
```

**结果**: (待填写)
- [ ] Test 16.1: PASS / FAIL
- [ ] Test 16.2.1: PASS / FAIL
- [ ] Test 16.2.2: PASS / FAIL
- [ ] Test 16.2.3: PASS / FAIL
- [ ] Test 16.3: PASS / FAIL

### 手动测试结果

**执行日期**: (待填写)
**执行人**: (待填写)

**Test 16.4 结果**: (待填写)
- [ ] 崩溃模拟成功
- [ ] 状态恢复日志正确
- [ ] 数据同步成功
- [ ] 无数据丢失

---

## 问题记录

如果测试过程中发现问题，请在此记录：

| 测试编号 | 问题描述 | 严重程度 | 状态 |
|---------|---------|---------|------|
| 示例    | 示例问题 | P0/P1/P2 | Open/Fixed |

---

## 下一步

测试通过后：
1. 使用 Codex MCP 审核代码改动
2. 执行 `flutter analyze` 验证代码质量
3. Git 提交：`git commit -m "feat(flutter): 完成 Task 16 - 同步流程验证 (Checkpoint E)"`
4. 继续 Task 17: 实现用户界面增强
