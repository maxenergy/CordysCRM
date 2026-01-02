# 企业导入问题诊断状态

## 当前状态 (2024-12-29 12:47)

### ✅ 已完成的工作

1. **后端修复**
   - ✅ 日期格式修复：使用 `insertWithDateConversion` 方法,指定 `jdbcType=DATE`
   - ✅ Mapper XML 已验证存在并包含正确方法
   - ✅ 后端已重新编译并启动 (PID: 287679)
   - ✅ DEBUG 日志已启用 (MyBatis + integration 包)

2. **环境验证**
   - ✅ MySQL 运行中 (Docker: cordys-mysql)
   - ✅ Redis 运行中 (Docker: cordys-redis)
   - ✅ ADB 已连接 (设备: d91a2f3)
   - ✅ Flutter 应用运行中 (PID: 32476)

3. **诊断工具**
   - ✅ 创建了增强诊断脚本 (`scripts/diagnose_import_error.sh`)
   - ✅ 创建了自动化测试脚本 (`scripts/auto_test_enterprise_import.sh`)
   - ✅ 创建了实时监控脚本 (`scripts/monitor_import_realtime.sh`)
   - ✅ 创建了修复指南文档 (`ENTERPRISE_IMPORT_FIX_GUIDE.md`)

### ⚠️ 当前问题

1. **API 认证问题**
   - 自动化测试脚本登录成功,但导入 API 返回 401
   - 可能原因：Session 管理、CSRF token、Shiro 权限配置

2. **日志捕获问题**
   - 后端日志监控未捕获到任何导入相关日志
   - 说明：可能是因为没有实际触发导入操作

3. **缺少完整错误堆栈**
   - 历史错误日志不完整,缺少 `Caused by` 部分
   - 需要：触发新的导入操作来捕获完整错误

### 📊 历史测试结果

- **之前测试**: 2/20 成功率
- **说明**: 日期格式修复部分有效,但存在其他问题
- **单条导入**: 也失败,排除批量特有问题

## 🎯 下一步行动

### 方案 A: 手动触发 + 实时监控 (推荐)

**步骤**:

1. **启动实时监控**:
   ```bash
   ./scripts/monitor_import_realtime.sh
   ```

2. **在 Flutter 应用中手动执行导入**:
   - 打开企业搜索页面
   - 搜索任意企业
   - 点击导入按钮 (单条或批量)

3. **观察监控输出**:
   - 查找 SQL 执行日志
   - 查找错误堆栈 (包括 `Caused by`)
   - 查找成功/失败标志

**优点**:
- ✅ 最直接,能捕获真实错误
- ✅ 实时反馈,立即看到问题
- ✅ 不需要解决认证问题

**缺点**:
- ❌ 需要手动操作

### 方案 B: 修复 API 认证

**步骤**:

1. **检查 Shiro 配置**:
   ```bash
   grep -r "anon" backend/crm/src/main/java/cn/cordys/config/ShiroConfig.java
   ```

2. **添加测试端点到匿名访问列表**:
   ```java
   filterChainDefinitionMap.put("/api/enterprise/import", "anon");
   ```

3. **重启后端并重新测试**

**优点**:
- ✅ 完全自动化
- ✅ 可重复执行

**缺点**:
- ❌ 需要修改代码并重启
- ❌ 可能引入安全问题

### 方案 C: 使用后端集成测试

**步骤**:

1. **查看现有集成测试**:
   ```bash
   cat backend/crm/src/test/java/cn/cordys/crm/integration/EnterpriseImportIT.java
   ```

2. **运行集成测试**:
   ```bash
   cd backend/crm
   mvn test -Dtest=EnterpriseImportIT
   ```

**优点**:
- ✅ 绕过认证
- ✅ 可重复执行
- ✅ 标准测试流程

**缺点**:
- ❌ 可能需要配置测试环境
- ❌ 不是真实的 Flutter 导入流程

## 🔍 根本原因分析

基于历史数据和当前状态,最可能的根本原因:

### 1. 数据库约束冲突 (概率: ⭐⭐⭐⭐⭐)

**证据**:
- 2/20 成功率说明日期格式修复有效
- 单条也失败,排除批量特有问题
- 部分成功说明代码逻辑正确

**可能的约束问题**:
- `credit_code` 唯一索引冲突
- `customer_id` 外键约束失败
- JSON 字段长度超限 (shareholders/executives/risks)

**验证方法**:
```sql
-- 检查唯一索引
SHOW INDEX FROM enterprise_profile WHERE Key_name LIKE '%credit%';

-- 检查字段类型
SHOW CREATE TABLE enterprise_profile;

-- 检查重复数据
SELECT credit_code, COUNT(*) 
FROM enterprise_profile 
GROUP BY credit_code 
HAVING COUNT(*) > 1;
```

**修复方法**:
```sql
-- 添加唯一索引 (如果不存在)
ALTER TABLE enterprise_profile 
ADD UNIQUE INDEX uk_credit_code_org (credit_code, organization_id);

-- 修改字段类型 (如果长度不够)
ALTER TABLE enterprise_profile 
MODIFY COLUMN shareholders TEXT,
MODIFY COLUMN executives TEXT,
MODIFY COLUMN risks TEXT;
```

### 2. Mapper 未正确加载 (概率: ⭐⭐)

**证据**:
- 虽然 XML 文件存在,但可能未被 MyBatis 识别

**验证方法**:
- 查看后端启动日志中的 Mapper 加载信息
- 触发导入并查看 `hasStatement` 日志

**修复方法**:
- 确认已重新编译: `mvn clean compile`
- 确认已重启后端

### 3. 并发冲突 (概率: ⭐⭐)

**证据**:
- 批量导入时可能多个请求同时处理相同企业

**修复方法**:
- 添加唯一索引 (数据库层面)
- 或添加 synchronized (应用层面)

## 📝 推荐执行顺序

1. **立即执行**: 方案 A (手动触发 + 实时监控)
   - 目的：捕获完整错误堆栈
   - 时间：5 分钟

2. **根据错误修复**: 
   - 如果是数据库约束：执行 SQL 修复
   - 如果是 Mapper 未加载：重新编译并重启
   - 如果是其他错误：根据堆栈定位

3. **验证修复**: 再次手动触发导入
   - 目的：确认问题已解决
   - 时间：2 分钟

4. **自动化测试**: 运行自动化测试脚本
   - 目的：确保可重复性
   - 时间：3 分钟

## 🛠️ 快速命令参考

```bash
# 启动实时监控
./scripts/monitor_import_realtime.sh

# 检查数据库约束
docker exec cordys-mysql mysql -uroot -p123456 cordys_crm -e "SHOW CREATE TABLE enterprise_profile;"

# 检查重复数据
docker exec cordys-mysql mysql -uroot -p123456 cordys_crm -e "SELECT credit_code, COUNT(*) FROM enterprise_profile GROUP BY credit_code HAVING COUNT(*) > 1;"

# 查看后端日志
tail -f /proc/287679/fd/1 | grep -E "企业|enterprise|import|Exception|Error"

# 查看 Flutter 日志
adb logcat | grep -E "cordyscrm|enterprise|import"
```

## 📚 相关文档

- `ENTERPRISE_IMPORT_FIX_GUIDE.md` - 详细修复指南
- `ENTERPRISE_IMPORT_TROUBLESHOOTING.md` - 完整排查指南
- `BATCH_IMPORT_FIX_SUMMARY.md` - 日期格式修复总结
- `scripts/diagnose_import_error.sh` - 诊断脚本
- `scripts/monitor_import_realtime.sh` - 实时监控脚本

## ✅ 成功标志

导入成功的标志:
- ✅ HTTP 状态码 200
- ✅ 后端日志显示 `插入企业档案成功`
- ✅ 数据库中有新记录
- ✅ `reg_date` 是日期格式 (如 `2021-01-01`)
- ✅ Flutter 应用显示导入成功提示

## 🚨 注意事项

1. **不要盲目修改代码** - 先捕获完整错误堆栈
2. **保持后端运行** - 避免中断监控
3. **记录所有错误** - 便于后续分析
4. **一次只改一个地方** - 便于定位问题
5. **测试前备份数据库** - 避免数据丢失
