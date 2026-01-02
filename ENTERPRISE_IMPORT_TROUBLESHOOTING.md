# 企业批量导入问题排查指南

## 快速修复

**如果你想快速修复问题，请直接运行：**

```bash
./scripts/fix_enterprise_import.sh
```

这个脚本会自动执行：诊断 → 重新编译 → 修复数据库 → 重启后端 → 验证测试

**详细修复指南**：请查看 `ENTERPRISE_IMPORT_FIX_GUIDE.md`

---

## 问题描述

Flutter 企业批量导入功能报 MyBatis 异常，错误堆栈不完整，只看到 Plugin 层的异常。

## 快速排查步骤

### 步骤 1：启动调试模式后端

在一个终端运行：

```bash
./scripts/debug_enterprise_import.sh
```

这个脚本会：
1. 停止现有后端服务
2. 重新编译代码
3. 验证 Mapper XML 文件
4. 启动后端并启用详细的 SQL 日志

**关键日志输出**：
- `### SQL:` - 实际执行的 SQL 语句
- `### Parameters:` - SQL 参数值
- `### Error updating database.` - 数据库错误
- `### Cause:` - **根本原因（最重要）**

### 步骤 2：运行单条导入测试

在另一个终端运行：

```bash
./scripts/test_enterprise_import_single.sh
```

这个脚本会：
1. 检查后端服务状态
2. 登录获取 token
3. 导入一条测试企业数据
4. 显示导入结果

**预期结果**：
- ✓ 导入成功：说明基本功能正常
- ✗ 导入失败：查看后端日志中的 `Caused by` 部分

### 步骤 3：检查数据库约束

连接到 MySQL 数据库并运行：

```bash
mysql -u root -p cordys_crm < scripts/check_enterprise_constraints.sql
```

这个脚本会检查：
1. 表结构和约束
2. `credit_code` 重复记录
3. `customer_id` 外键关联
4. 字段长度超限
5. 日期字段异常
6. 最近导入的企业

## 常见问题和解决方案

### 问题 1：Duplicate entry for key 'credit_code'

**原因**：尝试导入已存在的企业（信用代码重复）

**解决方案**：
1. 检查是否是并发导入导致的
2. 确认前端是否正确处理了冲突提示
3. 如果需要更新，使用 `/api/enterprise/import/force` 接口

**验证**：
```sql
SELECT credit_code, COUNT(*) 
FROM enterprise_profile 
GROUP BY credit_code 
HAVING COUNT(*) > 1;
```

### 问题 2：Data too long for column 'shareholders'

**原因**：JSON 字段（shareholders/executives/risks）数据过长

**解决方案**：
1. 检查字段定义：
   ```sql
   SHOW CREATE TABLE enterprise_profile;
   ```
2. 如果是 `VARCHAR`，建议改为 `TEXT`：
   ```sql
   ALTER TABLE enterprise_profile 
   MODIFY COLUMN shareholders TEXT,
   MODIFY COLUMN executives TEXT,
   MODIFY COLUMN risks TEXT;
   ```

### 问题 3：Cannot add or update a child row

**原因**：`customer_id` 外键约束失败

**解决方案**：
1. 检查 `customer` 表中是否存在对应的记录
2. 确认 `EnterpriseService.createEnterpriseProfile` 中先插入 `customer` 再插入 `enterprise_profile`

**验证**：
```sql
SELECT ep.customer_id, c.id
FROM enterprise_profile ep
LEFT JOIN customer c ON ep.customer_id = c.id
WHERE c.id IS NULL;
```

### 问题 4：Incorrect date value for column 'reg_date'

**原因**：日期转换失败（这个问题应该已经修复）

**验证修复是否生效**：
1. 检查后端日志中是否有：
   ```
   hasStatement(insertWithDateConversion)=true
   准备插入企业档案: regDate=2021-01-01, regDateClass=java.time.LocalDate
   ```
2. 如果 `hasStatement=false`，说明 Mapper XML 未加载

**解决方案**：
1. 确认 `ExtEnterpriseProfileMapper.xml` 在 `target/classes` 中
2. 重新编译：`mvn clean compile -DskipTests`
3. 重启后端服务

### 问题 5：后端服务不响应（100500 错误）

**原因**：后端进程崩溃或数据库连接失败

**解决方案**：
1. 检查后端进程：
   ```bash
   ps aux | grep java
   ```
2. 检查数据库连接：
   ```bash
   mysql -u root -p -e "SELECT 1"
   ```
3. 查看后端错误日志：
   ```bash
   tail -f logs/enterprise-import-debug.log
   ```

## 并发问题排查

### 测试并发导入

```bash
# 并发导入 10 次相同的企业
seq 1 10 | xargs -n1 -P5 -I{} curl -s -X POST http://localhost:8080/api/enterprise/import \
  -H "Content-Type: application/json" \
  -H "X-AUTH-TOKEN: <your-token>" \
  -d '{"companyName":"并发测试企业","creditCode":"91110000CONCURRENT"}'
```

### 预期结果

- 第 1 次：成功创建
- 第 2-10 次：返回冲突提示或更新成功

### 如果出现重复记录

说明存在并发竞态条件，需要：

1. **添加数据库唯一索引**（推荐）：
   ```sql
   ALTER TABLE enterprise_profile 
   ADD UNIQUE INDEX uk_credit_code_org (credit_code, organization_id);
   ```

2. **应用层加锁**：
   ```java
   @Transactional(rollbackFor = Exception.class)
   public synchronized EnterpriseImportResponse importEnterprise(...) {
       // 现有逻辑
   }
   ```

## 日志分析技巧

### 关键日志标识

在后端日志中搜索以下关键词：

1. **SQL 执行**：
   ```
   ### SQL: INSERT INTO enterprise_profile
   ### Parameters: ...
   ```

2. **错误根因**：
   ```
   ### Cause: java.sql.SQLException: ...
   ```

3. **MyBatis 映射**：
   ```
   hasStatement(insertWithDateConversion)=true
   Mapper class: com.sun.proxy.$Proxy123
   ```

4. **日期转换**：
   ```
   准备插入企业档案: regDate=2021-01-01, regDateClass=java.time.LocalDate
   ```

### 使用 grep 过滤日志

```bash
# 查看所有 SQL 语句
grep "### SQL:" logs/enterprise-import-debug.log

# 查看所有错误
grep -A 10 "### Cause:" logs/enterprise-import-debug.log

# 查看企业导入相关日志
grep "企业" logs/enterprise-import-debug.log
```

## 完整测试流程

### 1. 环境准备

```bash
# 启动数据库
docker-compose up -d mysql redis

# 或使用脚本
./scripts/start_databases.sh
```

### 2. 启动调试模式后端

```bash
./scripts/debug_enterprise_import.sh
```

### 3. 运行测试

```bash
# 单条导入测试
./scripts/test_enterprise_import_single.sh

# 批量导入测试（如果单条成功）
./scripts/test_batch_import_ui.sh
```

### 4. 检查数据库

```bash
mysql -u root -p cordys_crm < scripts/check_enterprise_constraints.sql
```

### 5. 分析日志

```bash
# 查看完整日志
less logs/enterprise-import-debug.log

# 查看错误
grep -A 20 "### Cause:" logs/enterprise-import-debug.log
```

## 预期的成功日志

```
INFO  - 准备插入企业档案: id=xxx, regDate=2021-01-01, regDateClass=java.time.LocalDate
DEBUG - Mapper class: com.sun.proxy.$Proxy123
DEBUG - MyBatis hasStatement(insertWithDateConversion)=true
DEBUG - ==>  Preparing: INSERT INTO enterprise_profile (..., reg_date, ...) VALUES (..., ?, ...)
DEBUG - ==> Parameters: ..., 2021-01-01(LocalDate), ...
DEBUG - <==    Updates: 1
INFO  - 插入企业档案成功: id=xxx, 影响行数=1
```

## 需要提供的信息

如果问题仍未解决，请提供以下信息：

1. **完整错误堆栈**（包括 `Caused by` 部分）
2. **SQL 日志**（`### SQL:` 和 `### Parameters:`）
3. **数据库约束检查结果**
4. **测试数据**（脱敏后的 JSON）
5. **后端版本信息**（Git commit hash）

## 相关文件

- `backend/crm/src/main/java/cn/cordys/crm/integration/service/EnterpriseService.java` - 服务类
- `backend/crm/src/main/java/cn/cordys/crm/integration/mapper/ExtEnterpriseProfileMapper.xml` - Mapper XML
- `backend/crm/src/main/java/cn/cordys/crm/integration/controller/EnterpriseController.java` - 控制器
- `BATCH_IMPORT_DEBUG_GUIDE.md` - 之前的调试指南
- `BATCH_IMPORT_FIX_SUMMARY.md` - 修复总结

## 联系支持

如果以上步骤都无法解决问题，请：

1. 收集完整的日志和错误信息
2. 记录复现步骤
3. 提供测试数据（脱敏）
4. 联系开发团队进行深入排查

