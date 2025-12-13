package cn.cordys.config;

import cn.cordys.security.SessionConstants;
import cn.cordys.security.SessionUser;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.apache.commons.lang3.StringUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.session.Session;
import org.springframework.session.data.redis.RedisIndexedSessionRepository;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Map;

/**
 * 在 Shiro 之前处理 /api/user/current 请求。
 * 用于 Chrome 扩展等外部客户端通过 Session ID 获取当前用户信息。
 * 
 * 支持的认证方式：
 * - Authorization: Bearer {sessionId}
 * - Authorization: Session {sessionId}
 */
public class UserCurrentBypassFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(UserCurrentBypassFilter.class);
    private static final String SESSION_AUTH_PREFIX = "Session ";
    private static final String BEARER_AUTH_PREFIX = "Bearer ";

    private final RedisIndexedSessionRepository sessionRepository;
    private final ObjectMapper objectMapper;

    public UserCurrentBypassFilter(RedisIndexedSessionRepository sessionRepository, ObjectMapper objectMapper) {
        this.sessionRepository = sessionRepository;
        this.objectMapper = objectMapper;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = getPathWithinApplication(request);
        return !(StringUtils.equals(path, "/api/user/current") 
                || StringUtils.startsWith(path, "/api/user/current/"));
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {

        log.info("[UserCurrentBypassFilter] Processing request: {} {}", request.getMethod(), request.getRequestURI());

        // CORS 预检请求处理
        if ("OPTIONS".equalsIgnoreCase(request.getMethod())) {
            handleCorsPreflight(request, response);
            return;
        }

        // 只允许 GET 请求
        if (!"GET".equalsIgnoreCase(request.getMethod())) {
            response.setStatus(HttpServletResponse.SC_METHOD_NOT_ALLOWED);
            return;
        }

        // 设置 CORS 响应头
        setCorsHeaders(request, response);

        // 提取 Session ID
        String sessionId = extractSessionId(request.getHeader("Authorization"));
        if (StringUtils.isBlank(sessionId)) {
            log.warn("[UserCurrentBypassFilter] No valid session ID in Authorization header");
            sendUnauthorized(response);
            return;
        }

        log.info("[UserCurrentBypassFilter] Validating session: {}", maskSessionId(sessionId));

        try {
            // 从 Redis 获取 Session
            Session session = sessionRepository.findById(sessionId);
            if (session == null) {
                log.warn("[UserCurrentBypassFilter] Session not found: {}", maskSessionId(sessionId));
                sendUnauthorized(response);
                return;
            }

            // 获取用户信息
            SessionUser sessionUser = session.getAttribute(SessionConstants.ATTR_USER);
            if (sessionUser == null || StringUtils.isBlank(sessionUser.getId())) {
                log.warn("[UserCurrentBypassFilter] No valid user in session");
                sendUnauthorized(response);
                return;
            }

            // 设置 Session ID 并返回用户信息
            sessionUser.setSessionId(sessionId);
            log.info("[UserCurrentBypassFilter] Authentication successful for user: {}", sessionUser.getId());
            sendSuccess(response, sessionUser);
        } catch (Exception e) {
            log.error("[UserCurrentBypassFilter] Session validation failed: {}", e.getMessage(), e);
            sendUnauthorized(response);
        }
    }

    /**
     * 获取应用内路径（去除 context path）
     */
    private static String getPathWithinApplication(HttpServletRequest request) {
        String uri = request.getRequestURI();
        String contextPath = request.getContextPath();
        if (StringUtils.isNotBlank(contextPath) && uri.startsWith(contextPath)) {
            return uri.substring(contextPath.length());
        }
        return uri;
    }

    /**
     * 从 Authorization 头提取 Session ID
     */
    private static String extractSessionId(String authorization) {
        if (StringUtils.isBlank(authorization)) {
            return null;
        }
        String trimmed = authorization.trim();
        if (StringUtils.startsWithIgnoreCase(trimmed, BEARER_AUTH_PREFIX)) {
            return StringUtils.trimToNull(trimmed.substring(BEARER_AUTH_PREFIX.length()));
        }
        if (StringUtils.startsWithIgnoreCase(trimmed, SESSION_AUTH_PREFIX)) {
            return StringUtils.trimToNull(trimmed.substring(SESSION_AUTH_PREFIX.length()));
        }
        return null;
    }

    /**
     * 掩码 Session ID 用于日志输出
     */
    private static String maskSessionId(String sessionId) {
        if (sessionId == null || sessionId.length() < 8) {
            return "***";
        }
        return sessionId.substring(0, 4) + "****" + sessionId.substring(sessionId.length() - 4);
    }

    /**
     * 发送成功响应
     */
    private void sendSuccess(HttpServletResponse response, SessionUser sessionUser) throws IOException {
        response.setStatus(HttpServletResponse.SC_OK);
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        objectMapper.writeValue(response.getOutputStream(), sessionUser);
    }

    /**
     * 发送未授权响应
     */
    private void sendUnauthorized(HttpServletResponse response) throws IOException {
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        objectMapper.writeValue(response.getOutputStream(), Map.of("message", "Unauthorized"));
    }

    /**
     * 处理 CORS 预检请求
     */
    private static void handleCorsPreflight(HttpServletRequest request, HttpServletResponse response) {
        setCorsHeaders(request, response);
        String requestHeaders = request.getHeader("Access-Control-Request-Headers");
        if (StringUtils.isNotBlank(requestHeaders)) {
            response.setHeader("Access-Control-Allow-Headers", requestHeaders);
        }
        response.setHeader("Access-Control-Allow-Methods", "GET,OPTIONS");
        response.setHeader("Access-Control-Max-Age", "3600");
        response.setStatus(HttpServletResponse.SC_NO_CONTENT);
    }

    /**
     * 设置 CORS 响应头
     */
    private static void setCorsHeaders(HttpServletRequest request, HttpServletResponse response) {
        String origin = request.getHeader("Origin");
        if (StringUtils.isBlank(origin)) {
            return;
        }
        response.setHeader("Access-Control-Allow-Origin", origin);
        response.setHeader("Vary", "Origin");
        response.setHeader("Access-Control-Allow-Credentials", "true");
    }
}
