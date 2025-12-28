# 批量导入企业调试指南

## 问题描述

在批量导入企业功能中，遇到日期转换错误。错误堆栈显示调用的是 `cn.cordys.mybatis.DataAccessLayer$Executor.insert` 而不是我们自定义的 `extEnterpriseProfileMapper.insertWithDateConversion` 方法。

## 问题分析

根据 Codex MCP 的分析，可能的原因包括：

1. **运行的代码路径仍在调用 BaseMapper.insert**（旧代码或另一条导入路径）
2. **当前改的 EnterpriseService 没被部署到运行环境**
3. **调用实际是另一个服务或接口**

## 已实施的解决方案

### 1. 代码检查

确认了以下内容：

- ✅ `EnterpriseService.java` 第487行确实调用了 `extEnterpriseProfileMapper.insertWithDateConversion(profile)`
- ✅ `ExtEnterpriseProfileMapper.xml` 中正确定义了 `insertWithDateConversion` 方法，并指定了 `jdbcType=DATE`
- ✅ MyBatis 配置正确：`@MapperScan(basePackages = {"cn.cordys.**.mapper"})`
- ✅ XML 文件已正确复制到 `target/classes` 目录

### 2. 添加调试日志

在 `EnterpriseService.java` 的 `createEnterpriseProfile` 方法中添加了以下调试日志：

```java
// 1. 注入 SqlSession
@Resource
private SqlSession sqlSession;

// 2. 在插入前添加调试日志
log.info("准备插入企业档案: id={}, regDate={}, regDateClass={}", 
        profile.getId(), profile.getRegDate(), 
        profile.getRegDate() != null ? profile.getRegDate().getClass().getName() : "null");
log.info("Mapper class: {}, Mapper toString: {}", 
        extEnterpriseProfileMapper.getClass().getName(),
        extEnterpriseProfileMapper.toString());

// 3. 检查 MyBatis 是否识别了我们的方法
if (sqlSession != null) {
    boolean hasStatement = sqlSession.getConfiguration().hasStatement(
            "cn.cordys.crm.integration.mapper.ExtEnterpriseProfileMapper.insertWithDateConversion");
    log.info("MyBatis hasStatement(insertWithDateConversion)={}", hasStatement);
} else {
    log.warn("SqlSession is null; cannot verify mapped statement availability.");
}

// 4. 打印调用堆栈（debug 级别）
log.debug("insertWithDateConversion call stack trace", new RuntimeException("trace"));

// 5. 执行插入
int result = extEnterpriseProfileMapper.insertWithDateConversion(profile);
log.info("插入企业档案成功: id={}, 影响行数={}", profile.getId(), result);
```

### 3. 编译和部署

```bash
# 编译代码
cd backend/crm
mvn clean compile -DskipTests

# 重启后端服务
mvn spring-boot:run
```

## 测试步骤

### 环境变量配置（可选）

测试脚本支持以下环境变量覆盖默认配置：

```bash
# 后端服务地址（默认：http://localhost:8080）
export BASE_URL="http://localhost:8080"

# 登录用户名（默认：admin）
export USERNAME="admin"

# 登录密码（默认：admin123）
export PASSWORD="admin123"

# 日志文件路径（默认：logs）
export LOG_PATH="logs"
```

**安全提示**：在共享环境中，建议使用环境变量而不是硬编码凭据。

### 方式一：使用测试脚本

```bash
# 运行调试测试脚本
./scripts/test_enterprise_import_debug.sh
```

该脚本会：
1. 检查后端服务状态
2. 编译最新代码
3. 准备测试数据
4. 获取登录 token
5. 调用企业导入接口
6. 检查后端日志

### 方式二：手动测试

1. **启动后端服务**：
   ```bash
   cd backend
   mvn spring-boot:run
   ```

2. **登录获取 token**：
   ```bash
   curl -X POST http://localhost:8080/api/login \
     -H "Content-Type: application/json" \
     -d '{
       "username": "admin",
       "password": "admin123"
     }'
   ```

3. **调用企业导入接口**：
   ```bash
   curl -X POST http://localhost:8080/api/enterprise/import \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer <TOKEN>" \
     -d '{
       "companyName": "测试企业调试",
       "creditCode": "91110000MA01234567",
       "legalPerson": "张三",
       "regCapital": "1000000",
       "regDate": 1609459200000,
       "address": "北京市朝阳区测试路123号",
       "status": "存续",
       "phone": "010-12345678",
       "email": "test@example.com"
     }'
   ```

4. **检查日志输出**：
   查看后端控制台或日志文件，关注以下信息：
   - `Mapper class:` - 应该显示为 MyBatis 代理类
   - `hasStatement(insertWithDateConversion)=` - 应该为 `true`
   - `插入企业档案成功` - 确认插入成功
   - 是否有 `DataAccessLayer$Executor.insert` 的错误堆栈

## 预期结果

### 成功的日志输出

```
INFO  - 准备插入企业档案: id=xxx, regDate=2021-01-01, regDateClass=java.time.LocalDate
INFO  - Mapper class: com.sun.proxy.$Proxy123, Mapper toString: ...
INFO  - MyBatis hasStatement(insertWithDateConversion)=true
INFO  - 插入企业档案成功: id=xxx, 影响行数=1
```

### 失败的日志输出

如果仍然看到 `DataAccessLayer$Executor.insert` 错误，可能的原因：

1. **代码未重新编译**：
   - 解决：`mvn clean compile -DskipTests`

2. **服务未重启**：
   - 解决：重启后端服务

3. **调用了其他路径**：
   - 检查是否有其他服务或接口也在导入企业
   - 搜索代码中是否还有 `enterpriseProfileMapper.insert` 的调用

4. **MyBatis 配置问题**：
   - 如果 `hasStatement=false`，说明 XML 映射未加载
   - 检查 `mybatis.mapper-locations` 配置
   - 检查 XML 文件是否在 classpath 中

## 下一步行动

根据测试结果：

### 如果 hasStatement=true 但仍报错

说明 MyBatis 配置正确，但运行时走了其他路径：
1. 检查是否有多个 `EnterpriseService` 实例
2. 检查是否有其他服务调用了 `BaseMapper.insert`
3. 使用 `log.debug` 的堆栈跟踪确认调用路径

### 如果 hasStatement=false

说明 MyBatis 未识别我们的方法：
1. 检查 XML namespace 是否正确
2. 检查 XML 文件是否在 classpath 中
3. 检查 `@MapperScan` 配置是否包含了我们的 mapper 包

**注意**：本项目使用 Maven 资源打包方式，XML 文件位于 `src/main/java` 目录下，通过父 POM 的资源配置自动复制到 `target/classes`。不需要配置 `mybatis.mapper-locations`。

相关配置在 `pom.xml` 中：
```xml
<build>
    <resources>
        <resource>
            <directory>src/main/java</directory>
            <includes>
                <include>**/*.xml</include>
            </includes>
        </resource>
        <resource>
            <directory>src/main/resources</directory>
        </resource>
    </resources>
</build>
```

### 如果成功

说明问题已解决，可以：
1. 移除调试日志（保留关键日志）
2. 运行完整的测试套件
3. 提交代码

## 相关文件

- `backend/crm/src/main/java/cn/cordys/crm/integration/service/EnterpriseService.java` - 服务类
- `backend/crm/src/main/java/cn/cordys/crm/integration/mapper/ExtEnterpriseProfileMapper.java` - Mapper 接口
- `backend/crm/src/main/java/cn/cordys/crm/integration/mapper/ExtEnterpriseProfileMapper.xml` - Mapper XML
- `backend/crm/src/main/java/cn/cordys/crm/integration/domain/EnterpriseProfile.java` - 实体类
- `backend/crm/src/main/java/cn/cordys/config/MybatisConfig.java` - MyBatis 配置

## 参考资料

- [MyBatis 类型处理器文档](https://mybatis.org/mybatis-3/zh/configuration.html#typeHandlers)
- [MyBatis Mapper 扫描配置](https://mybatis.org/spring-boot-starter/mybatis-spring-boot-autoconfigure/)
- [Java LocalDate 与 SQL DATE 转换](https://docs.oracle.com/javase/8/docs/api/java/time/LocalDate.html)
