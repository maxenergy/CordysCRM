# Task 16.4: 手动测试指南 - 应用崩溃恢复

## 测试目标

验证 SyncService 的状态恢复机制能够在应用崩溃后正确恢复同步状态，确保离线数据不丢失。

## 前置条件

1. 后端服务已启动
2. Flutter 应用已编译（桌面版推荐）
3. 已有测试账号可以登录

## 测试步骤

### 第一部分：准备测试环境

#### 1. 启动后端服务

```bash
cd backend
mvn spring-boot:run
```

等待服务启动完成，确认可以访问 http://localhost:8080

#### 2. 启动 Flutter 应用（桌面版）

```bash
cd mobile/cordyscrm_flutter
flutter run -d linux
```

或者使用快捷脚本：

```bash
./scripts/run_flutter_desktop.sh
```

#### 3. 登录系统

- 打开应用
- 使用测试账号登录
- 确认登录成功

---

### 第二部分：模拟同步中断

#### 4. 创建测试数据

在应用中创建一个新客户：

- 导航到"客户"页面
- 点击"添加客户"按钮
- 填写客户信息：
  - 客户名称：`测试客户-崩溃恢复-${时间戳}`
  - 信用代码：`91110000600037341L`
  - 其他必填字段
- 点击"保存"

#### 5. 观察同步状态

保存后，观察应用底部的同步状态指示器：

- 应该显示"同步中"或类似状态
- 如果同步太快完成，可以尝试：
  - 断开网络连接
  - 或在后端设置断点暂停响应

#### 6. 强制终止应用进程

**重要：必须在同步进行中时执行此步骤**

打开新的终端窗口，执行：

```bash
# 查找 Flutter 进程
ps aux | grep flutter | grep -v grep

# 输出示例：
# rogers    12345  2.5  1.2  /path/to/flutter_app

# 使用 kill -9 强制终止（替换为实际 PID）
kill -9 12345
```

或者使用系统监视器（System Monitor）：
- 找到 Flutter 应用进程
- 右键 → "强制终止"

**验证点**：应用应该立即关闭，没有任何保存或清理操作

---

### 第三部分：验证状态恢复

#### 7. 重新启动应用

```bash
cd mobile/cordyscrm_flutter
flutter run -d linux
```

#### 8. 观察启动日志

在终端中查找以下日志输出：

```
[SyncStateRecovery] 发现 X 个过期的处理中同步项，正在重置为待处理状态...
[SyncStateRecovery] 重置过期同步项: ID=xxx, entity=customers/xxx, operation=CREATE, attempts=X, lastUpdate=...
[SyncStateRecovery] 成功重置了 X 个过期的同步项
```

**预期结果**：
- 应该看到至少 1 个过期项被重置
- 日志应该包含刚才创建的客户数据

#### 9. 验证自动同步

等待几秒钟，观察：

- 同步状态指示器应该显示"同步中"
- 然后变为"同步成功"或"空闲"

#### 10. 验证数据完整性

在应用中检查：

- 导航到"客户"页面
- 查找刚才创建的测试客户
- 确认客户数据完整

在后端数据库中验证：

```sql
-- 连接到数据库
mysql -u root -p cordyscrm

-- 查询客户数据
SELECT * FROM customer 
WHERE name LIKE '测试客户-崩溃恢复%' 
ORDER BY created_at DESC 
LIMIT 5;

-- 查询同步队列（应该为空或没有该客户的记录）
SELECT * FROM sync_queue 
WHERE entity_type = 'customers' 
AND status = 'inProgress';
```

**预期结果**：
- 客户数据存在于数据库中
- sync_queue 表中没有处于 inProgress 状态的过期项

---

### 第四部分：边界条件测试

#### 11. 测试多个中断项

重复步骤 4-6，创建多个客户数据，然后在同步过程中强制终止应用。

**预期结果**：
- 重启后所有中断的同步项都应该被恢复
- 所有数据最终都应该成功同步

#### 12. 测试长时间中断

1. 创建客户数据
2. 在同步过程中强制终止应用
3. **等待 6 分钟**（超过 5 分钟阈值）
4. 重新启动应用

**预期结果**：
- 超过 5 分钟的 InProgress 项应该被识别为 stale
- 这些项应该被重置为 Pending 状态
- 自动触发同步

---

## 验证清单

完成测试后，确认以下检查点：

### 功能验证
- [ ] 应用崩溃后可以正常重启
- [ ] 启动时自动检测到 stale 的 InProgress 项
- [ ] Stale 项被正确重置为 Pending 状态
- [ ] 重置后自动触发同步
- [ ] 数据成功同步到服务器
- [ ] 没有数据丢失

### 日志验证
- [ ] 启动日志包含状态恢复信息
- [ ] 日志显示重置的项数
- [ ] 日志包含每个重置项的详细信息（ID、entity、operation、attempts）
- [ ] 同步日志显示成功完成

### 数据库验证
- [ ] 客户数据存在于数据库中
- [ ] sync_queue 表中没有过期的 InProgress 项
- [ ] attemptCount 字段正确记录重试次数

---

## 常见问题排查

### 问题 1：找不到 Flutter 进程

**解决方案**：
```bash
# 使用更详细的过滤
ps aux | grep -i flutter

# 或者使用 pgrep
pgrep -f flutter
```

### 问题 2：应用重启后没有看到恢复日志

**可能原因**：
1. 同步已经完成（太快）
2. 日志级别设置过高

**解决方案**：
- 在后端设置断点延迟响应
- 或者断开网络后再创建数据

### 问题 3：数据没有同步到服务器

**排查步骤**：
1. 检查网络连接
2. 检查后端服务是否运行
3. 查看应用日志中的错误信息
4. 检查 sync_queue 表中的 error_message 字段

---

## 测试完成后

### 1. 清理测试数据

```sql
-- 删除测试客户
DELETE FROM customer 
WHERE name LIKE '测试客户-崩溃恢复%';

-- 清理同步队列
DELETE FROM sync_queue 
WHERE entity_type = 'customers' 
AND entity_id NOT IN (SELECT id FROM customer);
```

### 2. 记录测试结果

在 `TASK_16_CHECKPOINT_E_TEST_PLAN.md` 中填写手动测试结果：

- 执行日期
- 执行人
- 测试结果（PASS/FAIL）
- 发现的问题（如有）

### 3. 更新任务状态

如果所有测试通过：

```bash
# 标记 Task 16 为完成
# 在 .kiro/specs/core-data-integrity/tasks.md 中更新状态
```

---

## 下一步

测试通过后：

1. 运行 `flutter analyze` 验证代码质量
2. Git 提交：
   ```bash
   git add .
   git commit -m "feat(flutter): 完成 Task 16 - 同步流程验证 (Checkpoint E)"
   ```
3. 继续 Task 17: 实现用户界面增强
