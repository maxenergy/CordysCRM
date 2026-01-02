# 企业导入问题修复指南

## 问题现状

**症状**：Flutter 企业批量导入和单条导入均失败，MyBatis 异常堆栈不完整

**错误特征**：
- 只看到 `Plugin.invoke` 层的异常
- 缺少关键的 `Caused by` 部分
- 2/20 成功率说明日期格式修复部分有效
- 单条导入也失败，排除批量特有问题

## 根本原因分析

基于历史修复记录和当前症状，可能的根本原因：

### 1. 后端服务未重启（最可能）
**概率**: ⭐⭐⭐⭐⭐

代码修改后未重新编译或重启，导致：
- Mapper XML 未重新加载
- `insertWithDateConversion` 方法不可用
- 仍在使用旧的 BaseMapper.insert()

**验证方法**：
```bash
# 检查 Mapper XML 是否在 classpath 中
ls -la backend/crm/target/classes/cn/cordys/crm/integration/mapper/ExtEnterpriseProfileMapper.xml

# 检查后端进程启动时间
ps aux | grep spring-boot
```

### 2. 数据库约束冲突
**概率**: ⭐⭐⭐⭐

可能的约束问题：
- `credit_code` 重复（唯一索引冲突）
- `customer_id` 外键约束失败
- JSON 字段长度超限（VARCHAR → TEXT）

**验证方法**：
```sql
-- 检查重复信用代码
SELECT credit_code, COUNT(*) 
FROM enterprise_profile 
GROUP BY credit_code 
HAVING COUNT(*) > 1;

-- 检查孤立记录
SELECT COUNT(*) 
FROM enterprise_profile ep 
LEFT JOIN customer c ON ep.customer_id = c.id 
WHERE c.id IS NULL;

-- 检查字段定义
SHOW CREATE TABLE enterprise_profile;
```

### 3. 并发写入冲突
**概率**: ⭐⭐⭐

多个请求同时导入相同企业，导致竞态条件。

### 4. 日志配置问题
**概率**: ⭐⭐

MyBatis 日志级别不够，无法看到完整的错误堆栈。

## 修复步骤

### 步骤 1：运行增强诊断脚本

```bash
./scripts/diagnose_import_error.sh
```

这个脚本会：
- ✅ 检查多个日志位置，查找完整的异常堆栈
- ✅ 验证 Mapper XML 是否存在且包含正确的方法
- ✅ 检查数据库约束和重复记录
- ✅ 检查后端进程状态
- ✅ 生成详细的诊断报告

**预期输出**：
- 完整的错误堆栈（包含 `Caused by`）
- Mapper XML 加载状态
- 数据库约束检查结果
- 诊断报告文件路径

### 步骤 2：根据诊断结果修复

#### 场景 A：Mapper XML 未加载

**症状**：
```
✗ ExtEnterpriseProfileMapper.xml 不存在
或
✗ insertWithDateConversion 方法未找到
```

**修复**：
```bash
# 重新编译后端
cd backend/crm
mvn clean compile -DskipTests

# 验证 XML 文件
ls -la target/classes/cn/cordys/crm/integration/mapper/ExtEnterpriseProfileMapper.xml

# 重启后端
cd ../..
./scripts/debug_enterprise_import.sh
```

#### 场景 B：数据库约束冲突

**症状**：
```
Duplicate entry 'xxx' for key 'credit_code'
或
Cannot add or update a child row: a foreign key constraint fails
```

**修复**：

1. **添加唯一索引**（推荐）：
```sql
-- 防止重复信用代码
ALTER TABLE enterprise_profile 
ADD UNIQUE INDEX uk_credit_code_org (credit_code, organization_id);
```

2. **修改字段类型**（如果字段长度超限）：
```sql
-- 将 JSON 字段改为 TEXT
ALTER TABLE enterprise_profile 
MODIFY COLUMN shareholders TEXT,
MODIFY COLUMN executives TEXT,
MODIFY COLUMN risks TEXT;
```

3. **清理孤立记录**：
```sql
-- 删除无效的企业档案
DELETE FROM enterprise_profile 
WHERE customer_id NOT IN (SELECT id FROM customer);
```

#### 场景 C：日期格式问题（应该已修复）

**症状**：
```
Incorrect date value: 'timestamp' for column 'reg_date'
```

**验证修复是否生效**：
```bash
# 检查后端日志
grep "hasStatement(insertWithDateConversion)" logs/enterprise-import-debug.log
grep "准备插入企业档案" logs/enterprise-import-debug.log
```

**预期输出**：
```
hasStatement(insertWithDateConversion)=true
准备插入企业档案: regDate=2021-01-01, regDateClass=java.time.LocalDate
```

如果看到 `hasStatement=false`，说明 Mapper 未加载，回到场景 A。

#### 场景 D：并发冲突

**症状**：
- 间歇性失败
- 相同数据有时成功有时失败

**修复**：

1. **数据库层面**（推荐）：
```sql
ALTER TABLE enterprise_profile 
ADD UNIQUE INDEX uk_credit_code_org (credit_code, organization_id);
```

2. **应用层面**（备选）：
```java
// EnterpriseService.java
@Transactional(rollbackFor = Exception.class)
public synchronized EnterpriseImportResponse importEnterprise(...) {
    // 现有逻辑
}
```

### 步骤 3：测试验证

```bash
# 单条导入测试
./scripts/test_enterprise_import_single.sh

# 查看后端日志
tail -f logs/enterprise-import-debug.log

# 检查数据库
mysql -u root -p123456 cordys_crm -e "
SELECT id, company_name, credit_code, reg_date 
FROM enterprise_profile 
ORDER BY create_time DESC 
LIMIT 5;"
```

**成功标志**：
- ✅ 导入返回 200 状态码
- ✅ 后端日志显示 `插入企业档案成功`
- ✅ 数据库中有新记录
- ✅ `reg_date` 是日期格式（如 `2021-01-01`）

### 步骤 4：批量测试

单条成功后，测试批量导入：

```bash
# 在 Flutter 中选择 3-5 个企业进行批量导入
# 实时监控后端日志
tail -f logs/enterprise-import-debug.log | grep -E "企业|SQL|Error"
```

## 快速修复命令

如果你确定问题是后端未重启，直接运行：

```bash
# 一键修复：重新编译 + 重启后端
cd backend/crm && \
mvn clean compile -DskipTests && \
cd ../.. && \
pkill -f spring-boot && \
./scripts/debug_enterprise_import.sh
```

## 预防措施

### 1. 添加数据库约束

```sql
-- 防止重复信用代码
ALTER TABLE enterprise_profile 
ADD UNIQUE INDEX uk_credit_code_org (credit_code, organization_id);

-- 确保 JSON 字段足够大
ALTER TABLE enterprise_profile 
MODIFY COLUMN shareholders TEXT,
MODIFY COLUMN executives TEXT,
MODIFY COLUMN risks TEXT;
```

### 2. 增强日志配置

在 `application.yml` 中：

```yaml
logging:
  level:
    cn.cordys.crm.integration: DEBUG
    org.apache.ibatis: DEBUG
    com.baomidou.mybatisplus: DEBUG
```

### 3. 添加健康检查

```bash
# 定期检查后端状态
curl http://localhost:8080/actuator/health

# 检查 Mapper 加载状态
curl http://localhost:8080/actuator/mappings | grep insertWithDateConversion
```

## 常见问题

### Q1: 为什么错误堆栈不完整？

**A**: 可能原因：
1. 日志级别不够（需要 DEBUG）
2. 异常被拦截器吞掉
3. 日志文件轮转导致丢失

**解决**：使用增强诊断脚本，它会检查多个日志位置。

### Q2: 为什么 2/20 成功？

**A**: 说明日期格式修复是有效的，但：
1. 后端进程在测试中途崩溃
2. 数据库连接池耗尽
3. 并发冲突导致部分失败

### Q3: 单条也失败说明什么？

**A**: 排除了批量特有的问题，聚焦于：
1. 后端服务状态
2. 数据库约束
3. Mapper 配置

## 联系支持

如果以上步骤都无法解决，请提供：

1. **诊断报告**：`logs/diagnostic_report_*.txt`
2. **完整错误堆栈**（包含 `Caused by`）
3. **测试数据**（脱敏后的 JSON）
4. **数据库约束检查结果**
5. **后端启动日志**（前 100 行）

## 相关文件

- `ENTERPRISE_IMPORT_TROUBLESHOOTING.md` - 详细排查指南
- `BATCH_IMPORT_FIX_SUMMARY.md` - 日期格式修复总结
- `scripts/diagnose_import_error.sh` - 增强诊断脚本
- `scripts/debug_enterprise_import.sh` - 调试模式启动脚本
- `backend/crm/src/main/java/cn/cordys/crm/integration/service/EnterpriseService.java`
- `backend/crm/src/main/java/cn/cordys/crm/integration/mapper/ExtEnterpriseProfileMapper.xml`
