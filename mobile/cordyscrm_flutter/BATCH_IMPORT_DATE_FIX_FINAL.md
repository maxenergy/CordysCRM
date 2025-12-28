# 批量导入日期格式错误修复 - 最终版本

## 问题描述

用户在 Flutter app 中批量导入企业时收到错误：
```
DioException [bad response]: 服务器繁忙，请稍后重试 (code: 100500)
```

后端日志显示真正的错误：
```
Caused by: com.mysql.cj.jdbc.exceptions.MysqlDataTruncation: 
Data truncation: Incorrect date value: '976464000000' for column 'reg_date' at row 1
```

## 根本原因

1. **字段类型不匹配**：`EnterpriseProfile.regDate` 字段类型从 `Long` 改为 `LocalDate`
2. **MyBatis 类型处理缺失**：MyBatis 没有配置 `LocalDate` 的类型处理器
3. **错误的数据绑定**：MyBatis 将 `LocalDate` 对象错误地序列化为 Long 值传给数据库

## 解决方案

### 1. 创建 LocalDate 类型处理器

文件：`backend/crm/src/main/java/cn/cordys/crm/common/mybatis/typehandler/LocalDateTypeHandler.java`

```java
@MappedTypes(LocalDate.class)
@MappedJdbcTypes(value = JdbcType.DATE, includeNullJdbcType = true)
public class LocalDateTypeHandler extends BaseTypeHandler<LocalDate> {
    @Override
    public void setNonNullParameter(PreparedStatement ps, int i, LocalDate parameter, JdbcType jdbcType) throws SQLException {
        ps.setDate(i, Date.valueOf(parameter));
    }
    // ... 其他方法
}
```

**关键点**：
- `@MappedTypes(LocalDate.class)` - 指定处理 LocalDate 类型
- `@MappedJdbcTypes(value = JdbcType.DATE, includeNullJdbcType = true)` - 映射到 SQL DATE，包括 null 值
- `Date.valueOf(parameter)` - 将 LocalDate 转换为 java.sql.Date

### 2. 配置 MyBatis 类型处理器包扫描

文件：`backend/app/src/main/resources/commons.properties`

```properties
# MyBatis Type Handlers
mybatis.type-handlers-package=cn.cordys.crm.common.mybatis.typehandler
```

### 3. 日期转换逻辑

文件：`backend/crm/src/main/java/cn/cordys/crm/integration/service/EnterpriseService.java`

```java
private void copyRequestToProfile(EnterpriseImportRequest request, EnterpriseProfile profile) {
    // ...
    if (request.getEstablishmentDate() != null) {
        // 将时间戳（毫秒）转换为 LocalDate
        profile.setRegDate(convertTimestampToLocalDate(request.getEstablishmentDate()));
    }
    // ...
}

private LocalDate convertTimestampToLocalDate(Long epochMilli) {
    if (epochMilli == null) {
        return null;
    }
    try {
        return Instant.ofEpochMilli(epochMilli)
                .atZone(ZoneId.systemDefault())
                .toLocalDate();
    } catch (Exception e) {
        log.warn("Failed to convert timestamp {} to LocalDate", epochMilli, e);
        return null;
    }
}
```

## 测试步骤

### 1. 验证后端启动

```bash
# 检查后端日志，确认没有 MyBatis 配置错误
tail -f /opt/cordys/logs/cordys-crm/info.log
```

### 2. 测试批量导入

1. 打开 Flutter app
2. 进入企业搜索页面
3. 搜索企业（例如："腾讯"）
4. 长按选择多个企业
5. 点击"批量导入"按钮
6. 观察导入结果

**预期结果**：
- 导入成功，显示成功/失败统计
- 不再出现 100500 错误
- 数据库中 `reg_date` 字段正确存储为 DATE 格式（YYYY-MM-DD）

### 3. 验证数据库

```sql
-- 查看最近导入的企业
SELECT id, company_name, reg_date, create_time 
FROM enterprise_profile 
ORDER BY create_time DESC 
LIMIT 10;

-- 验证 reg_date 格式
-- 应该显示为：2000-12-31（而不是 976464000000）
```

## 技术细节

### MyBatis 类型处理器工作原理

1. **注册阶段**：Spring Boot 启动时，MyBatis 扫描 `mybatis.type-handlers-package` 指定的包
2. **绑定阶段**：当 MyBatis 遇到 `LocalDate` 类型的字段时，自动使用 `LocalDateTypeHandler`
3. **转换阶段**：
   - **写入**：`setNonNullParameter` 将 `LocalDate` 转换为 `java.sql.Date`
   - **读取**：`getNullableResult` 将 `java.sql.Date` 转换为 `LocalDate`

### 为什么需要 includeNullJdbcType = true

- 默认情况下，MyBatis 对 null 值使用全局 `jdbcTypeForNull`（通常是 `OTHER`）
- 某些 MySQL 配置下，`OTHER` 类型可能导致错误
- 设置 `includeNullJdbcType = true` 确保 null 值也使用 `JdbcType.DATE`

## 相关文件

- `backend/crm/src/main/java/cn/cordys/crm/common/mybatis/typehandler/LocalDateTypeHandler.java` - 类型处理器
- `backend/app/src/main/resources/commons.properties` - MyBatis 配置
- `backend/crm/src/main/java/cn/cordys/crm/integration/service/EnterpriseService.java` - 业务逻辑
- `backend/crm/src/main/java/cn/cordys/crm/integration/domain/EnterpriseProfile.java` - 实体类

## Git 提交

```bash
git commit -m "fix(backend): 修复批量导入企业日期格式错误

- 添加 MyBatis LocalDate 类型处理器
- 配置类型处理器包扫描
- 修复 reg_date 字段从 Long 到 LocalDate 的映射问题
- 解决 'Incorrect date value' MySQL 错误"
```

## 后续改进建议

1. **添加集成测试**：创建测试用例验证 LocalDate 字段的插入和查询
2. **监控日志**：观察生产环境中是否还有类似的类型转换问题
3. **扩展类型处理器**：如果有其他 Java 8 时间类型（LocalDateTime, LocalTime），也需要添加相应的类型处理器

## 参考资料

- [MyBatis Type Handlers](https://mybatis.org/mybatis-3/configuration.html#typeHandlers)
- [Java 8 Date/Time API](https://docs.oracle.com/javase/8/docs/api/java/time/package-summary.html)
- [MySQL DATE Type](https://dev.mysql.com/doc/refman/8.0/en/datetime.html)
