# 批量导入日期格式错误修复 V2

## 问题描述

批量导入企业时，遇到日期格式错误：
```
Incorrect date value: '1110470400000' for column 'reg_date' at row 1
```

## 根本原因

1. **数据库字段类型**：`reg_date` 列是 `DATE` 类型
2. **Java 实体类型**：`EnterpriseProfile.regDate` 字段是 `LocalDate` 类型
3. **MyBatis 类型转换**：MyBatis 没有正确加载 `LocalDateTypeHandler`，导致将 Long 值直接发送到数据库

## 修复方案

### 方案 1：配置 type-handlers-package（未生效）

在 `backend/app/src/main/resources/commons.properties` 中添加：
```properties
mybatis.type-handlers-package=cn.cordys.crm.common.mybatis.typehandler
```

**问题**：Spring Boot 的 MyBatis 自动配置没有正确读取这个配置。

### 方案 2：在 MybatisConfig 中显式注册 TypeHandler（已实施）

在 `backend/crm/src/main/java/cn/cordys/config/MybatisConfig.java` 中添加：

```java
/**
 * 注册 LocalDate 类型处理器
 * 用于将 Java LocalDate 正确映射到 SQL DATE 类型
 *
 * @return LocalDateTypeHandler 实例
 */
@Bean
public cn.cordys.crm.common.mybatis.typehandler.LocalDateTypeHandler localDateTypeHandler() {
    return new cn.cordys.crm.common.mybatis.typehandler.LocalDateTypeHandler();
}
```

## 技术细节

### LocalDateTypeHandler 实现

```java
@MappedTypes(LocalDate.class)
@MappedJdbcTypes(value = JdbcType.DATE, includeNullJdbcType = true)
public class LocalDateTypeHandler extends BaseTypeHandler<LocalDate> {
    
    @Override
    public void setNonNullParameter(PreparedStatement ps, int i, LocalDate parameter, JdbcType jdbcType) throws SQLException {
        ps.setDate(i, Date.valueOf(parameter));
    }

    @Override
    public LocalDate getNullableResult(ResultSet rs, String columnName) throws SQLException {
        Date date = rs.getDate(columnName);
        return date != null ? date.toLocalDate() : null;
    }
    
    // ... 其他方法
}
```

### 数据转换流程

1. **前端发送**：时间戳（毫秒）`1110470400000`
2. **EnterpriseService 转换**：
   ```java
   private LocalDate convertTimestampToLocalDate(Long epochMilli) {
       return Instant.ofEpochMilli(epochMilli)
               .atZone(ZoneId.systemDefault())
               .toLocalDate();
   }
   ```
3. **LocalDateTypeHandler 转换**：`LocalDate` → `java.sql.Date`
4. **数据库存储**：DATE 类型

## 测试步骤

1. 启动后端服务
2. 启动 Flutter 应用
3. 进入企业搜索页面
4. 搜索企业（例如："腾讯"）
5. 长按选择多个企业
6. 点击"批量导入"
7. 观察导入结果

## 预期结果

- 导入成功，无日期格式错误
- 企业信息正确保存到数据库
- `reg_date` 字段正确存储为 DATE 类型

## 修改文件

1. `backend/crm/src/main/java/cn/cordys/config/MybatisConfig.java` - 添加 TypeHandler Bean
2. `backend/crm/src/main/java/cn/cordys/crm/common/mybatis/typehandler/LocalDateTypeHandler.java` - TypeHandler 实现（已存在）

## 编译和部署

```bash
# 编译后端
cd backend
mvn clean compile -DskipTests

# 重启后端
# 停止旧进程，启动新进程

# 编译 Flutter
cd mobile/cordyscrm_flutter
flutter build apk --debug

# 安装到设备
flutter install -d d91a2f3

# 运行
flutter run -d d91a2f3
```

## 日期：2025-12-28

## 状态：待测试
