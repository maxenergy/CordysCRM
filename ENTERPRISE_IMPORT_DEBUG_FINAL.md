# 企业导入问题最终调试方案

## 问题现状

**症状**：Flutter 企业批量导入和单条导入都失败，报 MyBatis 异常

**错误堆栈**：
```
org.apache.ibatis.plugin.Plugin.invoke(Plugin.java:61)
org.apache.ibatis.session.defaults.DefaultSqlSession.insert(DefaultSqlSession.java:184)
org.mybatis.spring.SqlSessionTemplate$SqlSessionInterceptor.invoke(SqlSessionTemplate.java:333)
... 109 more
```

**关键问题**：错误堆栈不完整，缺少 `Caused by` 部分，无法确定根本原因。

## 已完成的修复

1. ✅ 创建了 `ExtEnterpriseProfileMapper.xml` 显式指定 `jdbcType=DATE`
2. ✅ 修改 `EnterpriseService` 使用 `insertWithDateConversion` 方法
3. ✅ 添加了日期转换逻辑（`convertTimestampToLocalDate`）
4. ✅ 添加了调试日志检查 `hasStatement` 和 `regDate` 类型

## 新增的增强调试功能

### 1. 增强的异常捕获

在 `EnterpriseService.createEnterpriseProfile` 和 `EnterpriseController.importEnterprise` 中添加了完整的异常链记录：

```java
try {
    int result = extEnterpriseProfileMapper.insertWithDateConversion(profile);
    log.info("插入企业档案成功: id={}, 影响行数={}", profile.getId(), result);
} catch (Exception e) {
    log.error("插入企业档案失败: id={}, companyName={}, creditCode={}, regDate={}", 
            profile.getId(), profile.getCompanyName(), profile.getCreditCode(), profile.getRegDate(), e);
    // 记录完整的异常链
    Throwable cause = e;
    int depth = 0;
    while (cause != null && depth < 10) {
        log.error("  Cause[{}]: {} - {}", depth, cause.getClass().getName(), cause.getMessage());
        cause = cause.getCause();
        depth++;
    }
    throw e;
}
```

### 2. 增强的调试脚本

创建了 `scripts/debug_enterprise_import_enhanced.sh`，提供：

- ✅ 自动停止旧服务
- ✅ 清理旧日志
- ✅ 验证 Mapper XML 文件
- ✅ 重新编译项目
- ✅ 验证 Mapper XML 在 classpath 中
- ✅ 创建增强的 logback 配置
- ✅ 启动后端并启用详细日志
- ✅ 等待服务就绪

## 调试步骤

### 步骤 1：启动增强调试模式

```bash
./scripts/debug_enterprise_import_enhanced.sh
```

这个脚本会：
1. 停止现有后端
2. 重新编译代码
3. 验证 Mapper XML
4. 启动后端并启用详细日志

**预期输出**：
```
========================================
调试环境已就绪
========================================

后端服务: http://localhost:8081
后端 PID: 12345

日志文件:
  - 主日志: logs/enterprise-import-enhanced.log
  - SQL 日志: logs/enterprise-import-sql.log
```

### 步骤 2：实时监控日志

在另一个终端运行：

```bash
# 监控主日志
tail -f logs/enterprise-import-enhanced.log

# 或监控 SQL 日志
tail -f logs/enterprise-import-sql.log
```

### 步骤 3：运行单条导入测试

在第三个终端运行：

```bash
./scripts/test_enterprise_import_single.sh
```

### 步骤 4：分析日志

在日志中查找以下关键信息：

#### 4.1 Mapper 加载状态

```
DEBUG - Mapper class: com.sun.proxy.$Proxy123
DEBUG - MyBatis hasStatement(insertWithDateConversion)=true
```

**如果 `hasStatement=false`**：
- ❌ Mapper XML 未正确加载
- 解决方案：检查 `target/classes` 中是否有 XML 文件

#### 4.2 日期转换

```
INFO - 准备插入企业档案: id=xxx, regDate=2021-01-01, regDateClass=java.time.LocalDate
```

**如果 `regDateClass` 不是 `LocalDate`**：
- ❌ 日期转换失败
- 解决方案：检查 `convertTimestampToLocalDate` 方法

#### 4.3 SQL 执行

```
DEBUG - ==>  Preparing: INSERT INTO enterprise_profile (..., reg_date, ...) VALUES (..., ?, ...)
DEBUG - ==> Parameters: ..., 2021-01-01(LocalDate), ...
```

**如果参数是时间戳而不是日期**：
- ❌ `jdbcType=DATE` 未生效
- 解决方案：检查 Mapper XML 语法

#### 4.4 完整的错误堆栈

```
ERROR - 插入企业档案失败: id=xxx, companyName=测试企业, creditCode=91110000XXX, regDate=2021-01-01
ERROR -   Cause[0]: org.mybatis.spring.MyBatisSystemException - ...
ERROR -   Cause[1]: org.apache.ibatis.exceptions.PersistenceException - ...
ERROR -   Cause[2]: java.sql.SQLException - Duplicate entry '91110000XXX' for key 'credit_code'
```

**这是最关键的信息**，会显示真正的错误原因。

## 常见错误和解决方案

### 错误 1：Duplicate entry for key 'credit_code'

**原因**：尝试导入已存在的企业

**解决方案**：
```bash
# 检查重复记录
mysql -u root -p cordys_crm -e "
SELECT credit_code, COUNT(*) 
FROM enterprise_profile 
GROUP BY credit_code 
HAVING COUNT(*) > 1;
"

# 使用强制导入接口
curl -X POST http://localhost:8081/api/enterprise/import/force \
  -H "Content-Type: application/json" \
  -H "X-AUTH-TOKEN: <token>" \
  -d @test_data.json
```

### 错误 2：Data too long for column 'shareholders'

**原因**：JSON 字段数据过长

**解决方案**：
```sql
ALTER TABLE enterprise_profile 
MODIFY COLUMN shareholders TEXT,
MODIFY COLUMN executives TEXT,
MODIFY COLUMN risks TEXT;
```

### 错误 3：Cannot add or update a child row

**原因**：`customer_id` 外键约束失败

**解决方案**：
```bash
# 检查孤立的企业档案
mysql -u root -p cordys_crm -e "
SELECT ep.customer_id, c.id
FROM enterprise_profile ep
LEFT JOIN customer c ON ep.customer_id = c.id
WHERE c.id IS NULL;
"
```

确认 `EnterpriseService.createEnterpriseProfile` 中先插入 `customer` 再插入 `enterprise_profile`。

### 错误 4：Incorrect date value for column 'reg_date'

**原因**：日期转换失败（应该已修复）

**验证修复**：
1. 检查日志中的 `regDateClass=java.time.LocalDate`
2. 检查 SQL 参数中的日期格式：`2021-01-01(LocalDate)`

**如果仍然失败**：
```bash
# 检查 Mapper XML 是否在 classpath 中
ls -la backend/crm/target/classes/cn/cordys/crm/integration/mapper/ExtEnterpriseProfileMapper.xml

# 重新编译
cd backend
mvn clean compile -DskipTests
cd ..
```

### 错误 5：hasStatement=false

**原因**：Mapper XML 未加载

**解决方案**：
1. 检查 XML 文件位置：
   ```bash
   ls -la backend/crm/src/main/resources/cn/cordys/crm/integration/mapper/
   ```

2. 检查 namespace 是否正确：
   ```xml
   <mapper namespace="cn.cordys.crm.integration.mapper.ExtEnterpriseProfileMapper">
   ```

3. 重新编译并重启：
   ```bash
   ./scripts/debug_enterprise_import_enhanced.sh
   ```

## 数据库检查

运行数据库约束检查：

```bash
mysql -u root -p cordys_crm < scripts/check_enterprise_constraints.sql
```

这会检查：
- 表结构和约束
- 重复的 `credit_code`
- 孤立的 `customer_id`
- 字段长度超限
- 日期字段异常

## 并发测试

测试并发导入是否会产生重复记录：

```bash
# 获取 token
TOKEN=$(curl -s -X POST http://localhost:8081/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}' | jq -r '.data.token')

# 并发导入 10 次
seq 1 10 | xargs -n1 -P5 -I{} curl -s -X POST http://localhost:8081/api/enterprise/import \
  -H "Content-Type: application/json" \
  -H "X-AUTH-TOKEN: $TOKEN" \
  -d '{"companyName":"并发测试企业","creditCode":"91110000CONCURRENT"}'
```

**预期结果**：
- 第 1 次：成功创建
- 第 2-10 次：返回冲突提示或更新成功

**如果出现重复记录**：
```sql
-- 添加唯一索引
ALTER TABLE enterprise_profile 
ADD UNIQUE INDEX uk_credit_code_org (credit_code, organization_id);
```

## 完整测试流程

### 1. 环境准备

```bash
# 启动数据库
docker-compose up -d mysql redis
```

### 2. 启动调试模式

```bash
./scripts/debug_enterprise_import_enhanced.sh
```

### 3. 监控日志

```bash
# 终端 1：主日志
tail -f logs/enterprise-import-enhanced.log

# 终端 2：SQL 日志
tail -f logs/enterprise-import-sql.log
```

### 4. 运行测试

```bash
# 终端 3：单条导入测试
./scripts/test_enterprise_import_single.sh
```

### 5. 分析结果

查看日志中的：
- ✅ `hasStatement(insertWithDateConversion)=true`
- ✅ `regDateClass=java.time.LocalDate`
- ✅ SQL 参数：`2021-01-01(LocalDate)`
- ✅ `插入企业档案成功`

或者：
- ❌ 完整的错误堆栈（`Cause[0]`, `Cause[1]`, ...）

## 预期的成功日志

```
2025-12-29 01:30:00.123 INFO  EnterpriseController - 开始导入企业: companyName=测试企业, creditCode=91110000XXX
2025-12-29 01:30:00.124 INFO  EnterpriseService - 准备插入企业档案: id=xxx, regDate=2021-01-01, regDateClass=java.time.LocalDate
2025-12-29 01:30:00.125 DEBUG EnterpriseService - Mapper class: com.sun.proxy.$Proxy123
2025-12-29 01:30:00.126 DEBUG EnterpriseService - MyBatis hasStatement(insertWithDateConversion)=true
2025-12-29 01:30:00.127 DEBUG ExtEnterpriseProfileMapper - ==>  Preparing: INSERT INTO enterprise_profile (..., reg_date, ...) VALUES (..., ?, ...)
2025-12-29 01:30:00.128 DEBUG ExtEnterpriseProfileMapper - ==> Parameters: ..., 2021-01-01(LocalDate), ...
2025-12-29 01:30:00.129 DEBUG ExtEnterpriseProfileMapper - <==    Updates: 1
2025-12-29 01:30:00.130 INFO  EnterpriseService - 插入企业档案成功: id=xxx, 影响行数=1
2025-12-29 01:30:00.131 INFO  EnterpriseController - 企业导入完成: companyName=测试企业, status=SUCCESS
```

## 需要提供的信息

如果问题仍未解决，请提供：

1. **完整的错误堆栈**（包括所有 `Cause[N]`）
2. **SQL 日志**（`==> Preparing` 和 `==> Parameters`）
3. **Mapper 加载状态**（`hasStatement` 结果）
4. **日期转换日志**（`regDateClass` 值）
5. **数据库约束检查结果**
6. **测试数据**（脱敏后的 JSON）

## 相关文件

- `backend/crm/src/main/java/cn/cordys/crm/integration/service/EnterpriseService.java` - 增强的异常捕获
- `backend/crm/src/main/java/cn/cordys/crm/integration/controller/EnterpriseController.java` - 增强的异常捕获
- `backend/crm/src/main/java/cn/cordys/crm/integration/mapper/ExtEnterpriseProfileMapper.xml` - Mapper XML
- `scripts/debug_enterprise_import_enhanced.sh` - 增强的调试脚本
- `scripts/test_enterprise_import_single.sh` - 单条导入测试
- `scripts/check_enterprise_constraints.sql` - 数据库约束检查

## 下一步行动

1. **立即执行**：
   ```bash
   ./scripts/debug_enterprise_import_enhanced.sh
   ```

2. **监控日志**：
   ```bash
   tail -f logs/enterprise-import-enhanced.log
   ```

3. **运行测试**：
   ```bash
   ./scripts/test_enterprise_import_single.sh
   ```

4. **分析结果**：
   - 如果成功：问题已解决
   - 如果失败：查看完整的错误堆栈（`Cause[0]`, `Cause[1]`, ...）

5. **根据错误类型应用相应的解决方案**（见上文"常见错误和解决方案"）

## 总结

这次增强的调试方案提供了：

1. ✅ **完整的异常链记录**：不再丢失 `Caused by` 信息
2. ✅ **详细的 SQL 日志**：可以看到实际执行的 SQL 和参数
3. ✅ **Mapper 加载验证**：确认 XML 是否正确加载
4. ✅ **日期转换验证**：确认 `LocalDate` 转换是否正确
5. ✅ **自动化的调试环境**：一键启动完整的调试环境

现在可以准确定位问题的根本原因，而不是猜测。
