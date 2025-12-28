# 批量导入日期格式错误修复

## 问题描述

批量导入企业信息时出现错误：
```
Incorrect date value: '976464000000' for column 'reg_date' at row 1
```

## 根本原因

1. **数据库定义**：`enterprise_profile` 表的 `reg_date` 列定义为 `DATE` 类型
2. **Java 字段类型**：`EnterpriseProfile.regDate` 字段定义为 `Long` 类型（时间戳毫秒）
3. **类型不匹配**：MyBatis 将 Long 类型的时间戳（976464000000）直接作为字符串插入到 DATE 列，导致 MySQL 无法解析

## 修复方案

采用**方案A**：修改 Java 字段类型从 `Long` 改为 `LocalDate`

### 理由

1. **类型安全**：`LocalDate` 是 Java 8+ 推荐的日期类型，与数据库 DATE 类型语义一致
2. **自动转换**：MyBatis 原生支持 `LocalDate` 与 DATE 类型的自动转换
3. **代码清晰**：使用 `LocalDate` 比 `Long` 更清晰地表达"日期"的语义
4. **避免错误**：编译时类型检查，避免运行时错误

## 代码修改

### 1. EnterpriseProfile.java

```java
// 修改前
@Schema(description = "成立日期")
private Long regDate;

// 修改后
@Schema(description = "成立日期")
private LocalDate regDate;
```

### 2. EnterpriseService.java

添加时间戳到 LocalDate 的转换方法：

```java
/**
 * 将时间戳（毫秒）转换为 LocalDate
 */
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

在 `copyRequestToProfile` 方法中使用转换：

```java
if (request.getEstablishmentDate() != null) {
    // 将时间戳（毫秒）转换为 LocalDate
    profile.setRegDate(convertTimestampToLocalDate(request.getEstablishmentDate()));
}
```

修改 `toLocalEnterpriseItem` 方法：

```java
if (profile.getRegDate() != null) {
    item.setEstablishDate(profile.getRegDate().format(DateTimeFormatter.ISO_LOCAL_DATE));
}
```

## 测试验证

### 1. 编译验证

```bash
cd backend
mvn clean compile -DskipTests
```

结果：✅ 编译成功

### 2. 功能测试

1. 重启后端服务
2. 重新安装 Flutter 应用到 Android 设备
3. 测试批量导入功能

## 影响范围

### 修改的文件

- `backend/crm/src/main/java/cn/cordys/crm/integration/domain/EnterpriseProfile.java`
- `backend/crm/src/main/java/cn/cordys/crm/integration/service/EnterpriseService.java`

### 影响的功能

- 企业信息导入（单个和批量）
- 企业信息搜索（本地和混合搜索）
- 企业信息展示

### 兼容性

- **向前兼容**：新代码可以正确处理时间戳输入（通过转换方法）
- **数据库兼容**：`LocalDate` 与 DATE 类型完全兼容
- **API 兼容**：`EnterpriseImportRequest.establishmentDate` 仍然是 `Long` 类型，保持 API 不变

## 技术决策

### 为什么选择 LocalDate 而不是 Date？

1. **现代化**：`LocalDate` 是 Java 8+ 推荐的日期 API
2. **不可变**：`LocalDate` 是不可变对象，线程安全
3. **清晰语义**：`LocalDate` 明确表示"日期"，不包含时间和时区信息
4. **MyBatis 支持**：MyBatis 3.4+ 原生支持 `LocalDate` 与 DATE 的转换

### 为什么不在 Mapper XML 中转换？

1. **业务逻辑分离**：类型转换属于业务逻辑，应该在 Service 层处理
2. **可测试性**：在 Java 代码中转换更容易编写单元测试
3. **可维护性**：Java 代码比 XML 更容易维护和重构

## 后续优化建议

1. **统一日期处理**：考虑将项目中所有日期字段统一使用 `LocalDate` 或 `LocalDateTime`
2. **添加单元测试**：为 `convertTimestampToLocalDate` 方法添加单元测试
3. **数据迁移**：如果数据库中已有 Long 类型的日期数据，需要编写迁移脚本

## 相关文档

- [SELECTION_BAR_UI_FIX.md](./SELECTION_BAR_UI_FIX.md) - SelectionBar UI 修复
- [COMPILE_AND_RUN_STATUS.md](../COMPILE_AND_RUN_STATUS.md) - 编译和运行状态
- [QUICK_RUN_GUIDE.md](../QUICK_RUN_GUIDE.md) - 快速运行指南
