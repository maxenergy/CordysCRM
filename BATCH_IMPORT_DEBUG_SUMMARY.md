# 批量导入企业调试总结

## 问题描述

在批量导入企业功能中，遇到日期转换错误。错误堆栈显示调用的是 `cn.cordys.mybatis.DataAccessLayer$Executor.insert` 而不是我们自定义的 `extEnterpriseProfileMapper.insertWithDateConversion` 方法。

## 根本原因分析

根据 Codex MCP 的深入分析，问题的根本原因可能是：

1. **代码路径不一致**：运行的代码可能仍在使用旧版本，或者有其他路径调用了 `BaseMapper.insert`
2. **部署问题**：修改的代码未被正确编译或部署到运行环境
3. **MyBatis 配置问题**：XML 映射未被正确加载或识别

## 已实施的解决方案

### 1. 代码优化

#### 移除未使用的 BaseMapper 注入

```java
// 注意：不再使用 BaseMapper<EnterpriseProfile>，统一使用 ExtEnterpriseProfileMapper
// 以确保日期类型正确转换（LocalDate -> DATE）
// @Resource
// private BaseMapper<EnterpriseProfile> enterpriseProfileMapper;
```

**原因**：避免误用 BaseMapper，确保所有操作都通过 ExtEnterpriseProfileMapper 进行。

#### 添加条件调试日志

```java
// 调试模式：检查 Mapper 配置（仅在首次调用或出错时记录）
if (log.isDebugEnabled()) {
    log.debug("Mapper class: {}", extEnterpriseProfileMapper.getClass().getName());
    if (sqlSession != null) {
        boolean hasStatement = sqlSession.getConfiguration().hasStatement(
                "cn.cordys.crm.integration.mapper.ExtEnterpriseProfileMapper.insertWithDateConversion");
        if (!hasStatement) {
            log.error("MyBatis 未识别 insertWithDateConversion 方法！hasStatement={}", hasStatement);
            log.debug("Call stack trace", new RuntimeException("trace"));
        } else {
            log.debug("MyBatis hasStatement(insertWithDateConversion)={}", hasStatement);
        }
    } else {
        log.warn("SqlSession is null; cannot verify mapped statement availability.");
    }
}
```

**优化点**：
- 只在 DEBUG 级别记录详细信息，避免生产环境日志噪音
- 只在 `hasStatement=false` 时记录堆栈跟踪，减少性能开销
- 在错误情况下使用 ERROR 级别，便于快速定位问题

### 2. 测试脚本改进

创建了健壮的测试脚本 `scripts/test_enterprise_import_debug.sh`：

**改进点**：
- ✅ 支持环境变量配置（BASE_URL, USERNAME, PASSWORD, LOG_PATH）
- ✅ 兼容有无 jq 的环境
- ✅ 自动检测 DataAccessLayer$Executor.insert 错误并失败
- ✅ 提供清晰的错误提示和诊断信息
- ✅ 安全性：支持通过环境变量传递凭据

### 3. 文档完善

创建了完整的调试指南 `BATCH_IMPORT_DEBUG_GUIDE.md`：

**包含内容**：
- 问题描述和分析
- 解决方案详解
- 测试步骤（自动化和手动）
- 预期结果和故障排除
- 配置说明（Maven 资源打包方式）
- 相关文件列表

## 测试验证

### 启用 DEBUG 日志

在 `application.yml` 或 `application.properties` 中添加：

```yaml
logging:
  level:
    cn.cordys.crm.integration.service.EnterpriseService: DEBUG
```

或

```properties
logging.level.cn.cordys.crm.integration.service.EnterpriseService=DEBUG
```

### 运行测试

```bash
# 使用默认配置
./scripts/test_enterprise_import_debug.sh

# 使用自定义配置
BASE_URL=http://localhost:8080 \
USERNAME=admin \
PASSWORD=admin123 \
LOG_PATH=logs \
./scripts/test_enterprise_import_debug.sh
```

### 预期结果

**成功的日志输出**：
```
DEBUG - Mapper class: com.sun.proxy.$Proxy123
DEBUG - MyBatis hasStatement(insertWithDateConversion)=true
INFO  - 准备插入企业档案: id=xxx, regDate=2021-01-01, regDateClass=java.time.LocalDate
INFO  - 插入企业档案成功: id=xxx, 影响行数=1
```

**失败的日志输出**：
```
ERROR - MyBatis 未识别 insertWithDateConversion 方法！hasStatement=false
DEBUG - Call stack trace
```

## 下一步行动

### 如果测试通过

1. **清理调试代码**：
   - 保留关键的 INFO 级别日志
   - 移除或注释掉 DEBUG 级别的详细检查
   - 移除 SqlSession 注入（如果不再需要）

2. **添加单元测试**：
   - 测试 `insertWithDateConversion` 方法
   - 测试日期转换逻辑
   - 测试冲突检测和去重逻辑

3. **提交代码**：
   ```bash
   git add .
   git commit -m "fix(enterprise): 修复批量导入日期转换问题

   - 移除未使用的 BaseMapper 注入
   - 添加条件调试日志
   - 改进测试脚本
   - 完善调试文档
   
   Closes #XXX"
   ```

### 如果测试失败

根据错误类型采取相应措施：

#### hasStatement=false

说明 MyBatis 未加载 XML 映射：
1. 检查 XML 文件是否在 `target/classes` 中
2. 检查 namespace 是否正确
3. 检查 `@MapperScan` 配置
4. 重新编译：`mvn clean compile`

#### 仍然调用 DataAccessLayer$Executor.insert

说明代码路径不正确：
1. 确认服务已重启
2. 检查是否有其他服务调用了 BaseMapper
3. 使用堆栈跟踪确认调用路径
4. 检查是否有多个 EnterpriseService 实例

#### 其他错误

1. 查看完整的错误堆栈
2. 检查数据库连接和权限
3. 检查 LocalDateTypeHandler 是否正确注册
4. 咨询 Codex MCP 获取更多建议

## 技术要点

### MyBatis 类型处理

本项目使用自定义的 `LocalDateTypeHandler` 处理 `LocalDate` 与 SQL `DATE` 的转换：

```java
@MappedTypes(LocalDate.class)
@MappedJdbcTypes(JdbcType.DATE)
public class LocalDateTypeHandler extends BaseTypeHandler<LocalDate> {
    // ...
}
```

在 XML 中显式指定 `jdbcType=DATE`：

```xml
<insert id="insertWithDateConversion">
    INSERT INTO enterprise_profile (
        ...
        reg_date,
        ...
    ) VALUES (
        ...
        #{regDate,jdbcType=DATE},
        ...
    )
</insert>
```

### Maven 资源打包

本项目将 XML 文件放在 `src/main/java` 目录下，通过 Maven 资源配置自动打包：

```xml
<build>
    <resources>
        <resource>
            <directory>src/main/java</directory>
            <includes>
                <include>**/*.xml</include>
            </includes>
        </resource>
    </resources>
</build>
```

这种方式的优点：
- XML 和 Java 接口在同一目录，便于维护
- 不需要配置 `mybatis.mapper-locations`
- 符合 MyBatis 官方推荐的项目结构

## 参考资料

- [MyBatis 类型处理器文档](https://mybatis.org/mybatis-3/zh/configuration.html#typeHandlers)
- [MyBatis Mapper 扫描配置](https://mybatis.org/spring-boot-starter/mybatis-spring-boot-autoconfigure/)
- [Java LocalDate 与 SQL DATE 转换](https://docs.oracle.com/javase/8/docs/api/java/time/LocalDate.html)
- [Maven 资源过滤](https://maven.apache.org/plugins/maven-resources-plugin/)

## 致谢

感谢 Codex MCP 提供的深入分析和改进建议，帮助我们：
- 识别了代码路径不一致的根本原因
- 优化了调试日志的性能和可读性
- 改进了测试脚本的健壮性和安全性
- 完善了文档的完整性和准确性
