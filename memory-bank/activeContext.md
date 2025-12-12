# σ₄: Active Context
*v1.0 | Created: 2025-12-12 | Updated: 2025-12-12*
*Π: DEVELOPMENT | Ω: RESEARCH*

## 🔮 Current Focus
修复爱企查 Cookie 保存功能的 "No static resource" 错误

## 🔍 问题分析

### 后端错误信息
```
2025-12-12 18:08:47,769 ERROR cn.cordys.common.util.LogUtils: 189 - Method[error][No static resource]
```

### 前端错误显示
- 提示: "从消息体中未获取到数据 Cookie"
- 前端控制台: 无错误信息

### 代码路径
- **前端**: `frontend/packages/web/src/views/system/integration-config/index.vue`
- **前端 API**: `frontend/packages/lib-shared/api/modules/enterprise.ts`
- **后端 Controller**: `backend/crm/src/main/java/cn/cordys/crm/integration/controller/EnterpriseController.java`
- **异常处理器**: `backend/framework/src/main/java/cn/cordys/common/response/handler/RestControllerExceptionHandler.java`

### 关键发现

1. **后端路由配置正确**:
   - Controller: `@RequestMapping("/api/enterprise")`
   - 方法: `@PostMapping("/config/cookie")`
   - 完整路径: `/api/enterprise/config/cookie`

2. **前端请求路径正确**:
   - URL: `/api/enterprise/config/cookie`
   - 数据: `{ cookie: string }`

3. **"No static resource" 错误来源**:
   - 在 `RestControllerExceptionHandler.java` 第 156 行
   - 处理 `NoResourceFoundException` 异常
   - 这通常表示请求的路径不存在或无法路由到正确的 Controller

4. **可能的原因**:
   - ❌ 路径配置问题（已排除，路径正确）
   - ❌ 前端请求方法问题（已排除，使用 POST）
   - ⚠️ **可能是 Shiro 过滤器拦截了请求**
   - ⚠️ **可能是请求未携带正确的认证信息**
   - ⚠️ **可能是 CORS 或其他中间件问题**

## 🔍 深入分析

### 认证流程
1. **Shiro 过滤器链**: `apikey, csrf, authc`
   - ApiKeyFilter: 检查 API Key 或允许未认证请求通过
   - CsrfFilter: 验证 CSRF Token (需要用户已认证)
   - AuthFilter: 验证用户认证状态

2. **前端请求头配置** (正确):
   - `X-AUTH-TOKEN`: sessionId
   - `CSRF-TOKEN`: csrfToken
   - `Organization-Id`: orgId

3. **CsrfFilter 验证逻辑**:
   - 如果用户未认证,设置 `Authentication-Status: invalid` 并**继续处理**
   - 如果用户已认证,验证 CSRF Token 和 X-AUTH-TOKEN

### 问题根源推测

根据错误 "No static resource",可能的原因:

1. **请求路径问题**: 前端实际请求的路径可能与后端不匹配
2. **请求方法问题**: 可能发送了 OPTIONS 预检请求
3. **认证失败**: AuthFilter 返回 401,导致请求未到达 Controller
4. **CORS 问题**: 跨域请求被拦截

### 错误信息分析
- **"从消息体中未获取到数据 Cookie"**: 未在前端国际化文件中找到此字符串
- **可能来源**:
  1. 后端返回的错误消息 (response.data.message)
  2. 浏览器自动翻译
  3. Chrome 扩展的错误消息

## 🔄 Recent Changes
- ✅ 创建了 memory-bank 结构
- ✅ 分析了前后端请求流程
- ✅ 确认了 Shiro 认证链配置
- ✅ 搜索了前端国际化配置
- ✅ 创建了详细的解决方案文档 (solution.md)

## 🏁 Next Steps

**需要用户提供调试信息**:

请打开浏览器开发者工具 (F12),切换到 Network 标签,然后尝试保存 Cookie,并提供以下信息:

1. **请求信息**:
   - 请求 URL (完整路径)
   - 请求方法 (GET/POST/OPTIONS)
   - 请求头 (特别是 X-AUTH-TOKEN, CSRF-TOKEN, Content-Type)
   - 请求体内容

2. **响应信息**:
   - 响应状态码 (200/401/404/500)
   - 响应头
   - 响应体内容

3. **后端日志**:
   - 完整的错误堆栈信息
   - 是否有其他相关日志

**或者,我可以添加调试日志来帮助定位问题。**

