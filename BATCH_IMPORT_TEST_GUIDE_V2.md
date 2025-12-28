# 批量导入日期格式修复测试指南

## 修复内容

修复了批量导入企业时的日期格式错误：`Incorrect date value: 'timestamp' for column 'reg_date'`

**修复方案**：在 MyBatis XML Mapper 中显式指定 `jdbcType=DATE`，强制 `LocalDate` 正确转换为 SQL `DATE` 类型。

## 测试环境

- **后端**：已重启，Process ID: 14
- **Flutter 应用**：已部署到 Android 设备 PJT110 (d91a2f3)
- **修复时间**：2025-12-28 23:54

## 快速测试步骤

### 1. 确认服务状态

后端应该已经在运行（端口 8081）：
```bash
curl http://localhost:8081/actuator/health
```

### 2. 在 Flutter 应用中测试

1. **登录应用**
   - 打开 PJT110 设备上的 CordysCRM 应用
   - 使用测试账号登录

2. **进入企业搜索**
   - 点击底部导航栏的"企业"图标
   - 进入企业搜索页面

3. **搜索企业**
   - 在搜索框输入关键词（例如："腾讯"、"阿里"、"百度"）
   - 等待搜索结果加载

4. **选择多个企业**
   - **长按**任意一个企业卡片，进入选择模式
   - 底部会出现 SelectionBar（蓝色背景）
   - 点击其他企业卡片，选择至少 2-3 个企业
   - SelectionBar 显示已选择的数量

5. **批量导入**
   - 点击 SelectionBar 右侧的"批量导入"按钮
   - 观察导入进度对话框

### 3. 验证结果

**成功标志**：
- ✅ 导入进度对话框显示"导入中..."
- ✅ 导入完成后显示成功/失败统计卡片
- ✅ 成功数量 > 0
- ✅ 没有出现"服务器错误"或"100500"错误

**失败标志**：
- ❌ 导入失败，显示"服务器错误"
- ❌ 所有企业都导入失败
- ❌ 错误日志中出现"Incorrect date value"

### 4. 检查后端日志

如果导入失败，检查后端错误日志：
```bash
tail -50 /opt/cordys/logs/cordys-crm/error.log | grep -A 10 "Incorrect date value"
```

**修复成功**：应该没有"Incorrect date value"错误

**修复失败**：仍然出现日期格式错误，需要进一步调查

### 5. 检查数据库（可选）

验证导入的企业数据：
```sql
SELECT 
    id, 
    company_name, 
    reg_date,
    DATE_FORMAT(reg_date, '%Y-%m-%d') as formatted_date,
    create_time 
FROM enterprise_profile 
ORDER BY create_time DESC 
LIMIT 10;
```

**预期结果**：
- `reg_date` 字段显示为日期格式（例如：`2005-03-11`）
- 不是时间戳格式（例如：`1110470400000`）

## 常见问题

### Q1: 导入时显示"服务器错误"

**可能原因**：
1. 后端未启动或崩溃
2. 网络连接问题
3. 日期格式错误（如果修复未生效）

**解决方法**：
1. 检查后端进程是否运行
2. 查看后端错误日志
3. 重启后端服务

### Q2: 所有企业都导入失败

**可能原因**：
1. 企业数据中的日期字段为 null 或格式错误
2. 数据库连接问题
3. 权限问题

**解决方法**：
1. 查看后端日志中的具体错误信息
2. 检查数据库连接状态
3. 验证用户权限

### Q3: 部分企业导入成功，部分失败

**这是正常情况**：
- 重复的企业（相同信用代码）会被跳过或更新
- 数据不完整的企业可能导入失败
- 查看导入结果对话框中的详细信息

## 回滚方案

如果修复失败，需要回滚代码：

```bash
# 回滚到上一个提交
git reset --hard HEAD~1

# 重新编译后端
cd backend
mvn clean compile -DskipTests

# 重启后端
# 停止当前进程，然后启动新进程
```

## 技术细节

### 修复前的问题

```java
// BaseMapper.insert() 会将 LocalDate 当作 Long 插入
enterpriseProfileMapper.insert(profile);
// 导致 SQL: INSERT INTO enterprise_profile (..., reg_date, ...) VALUES (..., 1110470400000, ...)
// 错误: Incorrect date value: '1110470400000' for column 'reg_date'
```

### 修复后的方案

```xml
<!-- ExtEnterpriseProfileMapper.xml -->
<insert id="insertWithDateConversion">
    INSERT INTO enterprise_profile (..., reg_date, ...)
    VALUES (..., #{regDate,jdbcType=DATE}, ...)
</insert>
```

```java
// EnterpriseService.java
extEnterpriseProfileMapper.insertWithDateConversion(profile);
// 正确的 SQL: INSERT INTO enterprise_profile (..., reg_date, ...) VALUES (..., '2005-03-11', ...)
```

### 为什么这样修复有效？

1. **显式类型指定**：`#{regDate,jdbcType=DATE}` 明确告诉 MyBatis 使用 `DATE` 类型
2. **绕过泛型限制**：不依赖 BaseMapper 的泛型推断
3. **使用内置转换器**：MyBatis 内置了 `LocalDate` → `java.sql.Date` 的转换器

## 相关文档

- `mobile/cordyscrm_flutter/BATCH_IMPORT_DATE_FIX_V2.md` - 详细修复文档
- `backend/crm/src/main/java/cn/cordys/crm/integration/mapper/ExtEnterpriseProfileMapper.xml` - XML Mapper
- `backend/crm/src/main/java/cn/cordys/crm/integration/service/EnterpriseService.java` - 服务层

## 联系方式

如有问题，请查看：
- 后端日志：`/opt/cordys/logs/cordys-crm/error.log`
- Flutter 日志：`flutter logs` 或设备 logcat
