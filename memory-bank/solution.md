# 🔧 解决方案

## 问题诊断

根据代码分析,问题的根本原因是:

### 1. 后端 "No static resource" 错误
- 错误来源: `RestControllerExceptionHandler.handleNoResourceFoundException()`
- 触发条件: Spring Boot 找不到对应的资源/路径
- 可能原因:
  - 请求路径不正确
  - 请求方法不匹配 (GET vs POST)
  - Shiro 过滤器拦截导致请求未到达 Controller

### 2. 前端错误显示
- 前端显示的错误信息可能是后端返回的 404 错误消息
- 或者是浏览器自动翻译的结果

## 🎯 解决步骤

### 步骤 1: 验证请求路径和方法

**检查项**:
1. 前端请求 URL: `/api/enterprise/config/cookie` (POST)
2. 后端路由: `/api/enterprise/config/cookie` (POST)
3. 开发环境代理: `/front` → `http://localhost:8081/`

**建议操作**:
1. 打开浏览器开发者工具 (F12)
2. 切换到 Network 标签
3. 尝试保存 Cookie
4. 查看实际发送的请求:
   - 请求 URL
   - 请求方法 (应该是 POST)
   - 请求头 (X-AUTH-TOKEN, CSRF-TOKEN)
   - 请求体 (应该包含 `{ "cookie": "..." }`)
   - 响应状态码
   - 响应内容

### 步骤 2: 检查后端日志

**查看后端完整日志**:
```bash
tail -f /opt/cordys/logs/cordys-crm/error.log
```

或者在 IDEA 控制台查看完整的错误堆栈。

### 步骤 3: 可能的修复方案

#### 方案 A: 前端请求路径问题

如果发现前端实际请求的路径不是 `/api/enterprise/config/cookie`,需要检查:

1. `VITE_API_BASE_URL` 环境变量
2. Axios baseURL 配置
3. API 路径拼接逻辑

#### 方案 B: CORS 预检请求问题

如果是 OPTIONS 预检请求失败,需要在后端添加 CORS 配置:

```java
@Configuration
public class CorsConfig implements WebMvcConfigurer {
    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
                .allowedOrigins("*")
                .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
                .allowedHeaders("*")
                .allowCredentials(false)
                .maxAge(3600);
    }
}
```

#### 方案 C: Shiro 过滤器问题

如果是 Shiro 拦截导致,可以将该路径添加到白名单:

```java
// 在 ShiroFilter.java 的 addPublicPathFilters() 方法中添加:
FILTER_CHAIN_DEFINITION_MAP.put("/api/enterprise/config/cookie", "anon");
```

#### 方案 D: 请求体解析问题

如果后端无法解析请求体,检查:

1. Content-Type 是否为 `application/json`
2. 请求体格式是否正确: `{ "cookie": "..." }`
3. `@RequestBody` 注解是否正确

### 步骤 4: 临时调试方案

在 `EnterpriseController.saveIqichaCookie()` 方法开头添加日志:

```java
@PostMapping("/config/cookie")
@Operation(summary = "保存爱企查Cookie", description = "保存爱企查登录Cookie用于企业搜索")
public Map<String, Object> saveIqichaCookie(@RequestBody(required = false) Map<String, String> request) {
    log.info("=== 收到保存Cookie请求 ===");
    log.info("Request: {}", request);
    
    try {
        // ... 原有代码
    }
}
```

这样可以确认请求是否到达 Controller。

## 🔍 下一步行动

1. **立即执行**: 打开浏览器开发者工具,查看实际的网络请求
2. **检查后端日志**: 确认请求是否到达 Controller
3. **根据实际情况选择修复方案**

## 📝 预期结果

修复后:
- 后端不再报 "No static resource" 错误
- 前端能够成功保存 Cookie
- 显示 "配置保存成功" 消息

