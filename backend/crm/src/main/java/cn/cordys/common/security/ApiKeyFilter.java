package cn.cordys.common.security;

import cn.cordys.security.SessionConstants;
import cn.cordys.security.SessionUser;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.apache.commons.lang3.StringUtils;
import org.apache.shiro.SecurityUtils;
import org.apache.shiro.authc.UsernamePasswordToken;
import org.apache.shiro.web.filter.authc.AnonymousFilter;
import org.apache.shiro.web.util.WebUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.session.Session;
import org.springframework.session.data.redis.RedisIndexedSessionRepository;

import static cn.cordys.security.SessionConstants.ATTR_USER;

/**
 * 自定义过滤器，用于处理 Web 应用中的 API 密钥认证。
 * 继承 AnonymousFilter 支持 API 密钥认证、Session ID 认证和常规会话认证。
 */
public class ApiKeyFilter extends AnonymousFilter {

    private static final Logger log = LoggerFactory.getLogger(ApiKeyFilter.class);

    private static final String NO_PASSWORD = "no_pass";
    private static final String SESSION_AUTH_PREFIX = "Session ";
    private static final String BEARER_AUTH_PREFIX = "Bearer ";

    /** 标记当前请求是否使用 Session ID 认证 */
    private static final ThreadLocal<Boolean> SESSION_ID_AUTH = ThreadLocal.withInitial(() -> false);

    /**
     * Shiro 2.x: AnonymousFilter 基于 PathMatchingFilter/AdviceFilter，入口是 onPreHandle。
     * 在认证检查前执行 API Key 和 Session ID 认证。
     * 支持三种认证方式：
     * 1. API Key 认证：Authorization: accessKey:signature
     * 2. Session ID 认证：Authorization: Session xxx 或 Authorization: Bearer xxx
     * 3. 常规 Cookie Session 认证
     */
    @Override
    protected boolean onPreHandle(ServletRequest request, ServletResponse response, Object mappedValue) {
        HttpServletRequest httpRequest = WebUtils.toHttp(request);
        SESSION_ID_AUTH.set(false);

        log.info("[ApiKeyFilter] onPreHandle for: {} {}", httpRequest.getMethod(), httpRequest.getRequestURI());

        // 如果用户已认证，直接通过
        if (SecurityUtils.getSubject().isAuthenticated()) {
            return true;
        }

        // 尝试 Session ID 认证（用于 Chrome 扩展等外部客户端）
        if (trySessionIdAuth(httpRequest)) {
            log.info("[ApiKeyFilter] Session ID 认证成功");
            return true;
        }

        // 尝试 API Key 认证
        if (ApiKeyHandler.isApiKeyCall(httpRequest)) {
            String userId = ApiKeyHandler.getUser(httpRequest);
            if (StringUtils.isNotBlank(userId)) {
                SecurityUtils.getSubject().login(new UsernamePasswordToken(userId, NO_PASSWORD));
            }
        }

        // 对于 /api/user/current 路径，不设置 invalid 状态，让 Controller 处理认证
        // 这样可以避免 Shiro 过滤器链顺序问题
        String uri = httpRequest.getRequestURI();
        if (uri.startsWith("/api/user/current")) {
            log.info("[ApiKeyFilter] Skipping authentication status for /api/user/current");
            return true;
        }

        // 如果仍未认证，设置响应头为无效状态
        if (!SecurityUtils.getSubject().isAuthenticated()) {
            ((HttpServletResponse) response).setHeader(SessionConstants.AUTHENTICATION_STATUS, "invalid");
        }

        return true;
    }

    /**
     * 尝试使用 Session ID 进行认证。
     * 支持格式：Authorization: Session xxx 或 Authorization: Bearer xxx
     */
    private boolean trySessionIdAuth(HttpServletRequest request) {
        String authorization = request.getHeader(ApiKeyHandler.AUTHORIZATION);
        log.info("[ApiKeyFilter] trySessionIdAuth - Authorization header: {}", 
                 authorization != null ? authorization.substring(0, Math.min(20, authorization.length())) + "..." : "null");
        
        if (StringUtils.isBlank(authorization)) {
            log.info("[ApiKeyFilter] trySessionIdAuth - No Authorization header");
            return false;
        }

        String sessionId = null;
        if (authorization.startsWith(SESSION_AUTH_PREFIX)) {
            sessionId = authorization.substring(SESSION_AUTH_PREFIX.length()).trim();
            log.info("[ApiKeyFilter] trySessionIdAuth - Found Session prefix");
        } else if (authorization.startsWith(BEARER_AUTH_PREFIX)) {
            sessionId = authorization.substring(BEARER_AUTH_PREFIX.length()).trim();
            log.info("[ApiKeyFilter] trySessionIdAuth - Found Bearer prefix");
        }

        if (StringUtils.isBlank(sessionId)) {
            log.info("[ApiKeyFilter] trySessionIdAuth - No valid session ID extracted");
            return false;
        }

        log.info("[ApiKeyFilter] 尝试 Session ID 认证: {}", sessionId);

        // 从 Redis 获取 Session 并验证
        try {
            RedisIndexedSessionRepository sessionRepository = 
                cn.cordys.common.util.CommonBeanFactory.getBean(RedisIndexedSessionRepository.class);
            if (sessionRepository == null) {
                log.warn("[ApiKeyFilter] sessionRepository 为 null - CommonBeanFactory 可能未初始化");
                return false;
            }

            Session session = sessionRepository.findById(sessionId);
            if (session == null) {
                log.warn("[ApiKeyFilter] 未找到 Session: {}", sessionId);
                return false;
            }

            // 获取 Session 中的用户信息
            SessionUser sessionUser = session.getAttribute(ATTR_USER);
            if (sessionUser == null || StringUtils.isBlank(sessionUser.getId())) {
                log.warn("[ApiKeyFilter] Session 中没有有效用户信息");
                return false;
            }

            // 使用用户 ID 进行认证
            log.info("[ApiKeyFilter] Session ID 认证成功: userId={}", sessionUser.getId());
            SecurityUtils.getSubject().login(new UsernamePasswordToken(sessionUser.getId(), NO_PASSWORD));
            SESSION_ID_AUTH.set(true);
            return true;
        } catch (Exception e) {
            log.error("[ApiKeyFilter] Session ID 认证异常: {}", e.getMessage(), e);
            return false;
        }
    }

    /**
     * 在请求处理之后调用。此方法用于处理 API 密钥和 Session ID 退出逻辑。
     */
    @Override
    protected void postHandle(ServletRequest request, ServletResponse response) {
        HttpServletRequest httpRequest = WebUtils.toHttp(request);

        // 如果是 API 密钥请求或 Session ID 认证，且用户已认证，则注销用户
        boolean isApiKeyCall = ApiKeyHandler.isApiKeyCall(httpRequest);
        boolean isSessionIdAuth = SESSION_ID_AUTH.get();
        
        if ((isApiKeyCall || isSessionIdAuth) && SecurityUtils.getSubject().isAuthenticated()) {
            SecurityUtils.getSubject().logout();
        }
    }

    @Override
    public void afterCompletion(ServletRequest request, ServletResponse response, Exception exception) throws Exception {
        try {
            super.afterCompletion(request, response, exception);
        } finally {
            // 无论是否抛异常/是否执行到 postHandle，都确保清理 ThreadLocal
            SESSION_ID_AUTH.remove();
        }
    }
}
