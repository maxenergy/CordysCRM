package cn.cordys.config;

import cn.cordys.security.SessionConstants;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.session.web.http.HttpSessionIdResolver;

import java.util.Collections;
import java.util.List;

/**
 * 配置类，用于管理与会话相关的配置和清理操作。
 * <p>
 * 本类主要用于配置会话的 ID 解析器，并通过定时任务清理没有绑定用户的会话。
 * </p>
 *
 * @version 1.0
 */
@Configuration
public class SessionConfig {

    private static final String BEARER_PREFIX = "Bearer ";
    private static final String SESSION_PREFIX = "Session ";
    private static final String AUTHORIZATION_HEADER = "Authorization";

    /**
     * 创建自定义的 {@link HttpSessionIdResolver} Bean。
     * <p>
     * 支持多种会话 ID 解析方式：
     * <ul>
     *   <li>X-AUTH-TOKEN 请求头（Web 前端使用）</li>
     *   <li>Authorization: Bearer {sessionId}（Chrome 扩展、移动端使用）</li>
     *   <li>Authorization: Session {sessionId}（兼容格式）</li>
     * </ul>
     * </p>
     *
     * @return 配置好的 {@link HttpSessionIdResolver} 实例
     */
    private static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger(SessionConfig.class);

    @Bean
    public HttpSessionIdResolver sessionIdResolver() {
        return new HttpSessionIdResolver() {
            @Override
            public List<String> resolveSessionIds(HttpServletRequest request) {
                String uri = request.getRequestURI();
                
                // 优先从 X-AUTH-TOKEN 请求头获取（Web 前端）
                String xAuthToken = request.getHeader(SessionConstants.HEADER_TOKEN);
                if (xAuthToken != null && !xAuthToken.isBlank()) {
                    log.debug("[SessionIdResolver] {} - Found X-AUTH-TOKEN: {}...", uri, xAuthToken.substring(0, Math.min(8, xAuthToken.length())));
                    return Collections.singletonList(xAuthToken);
                }

                // 从 Authorization 请求头获取（Chrome 扩展、移动端）
                String authorization = request.getHeader(AUTHORIZATION_HEADER);
                if (authorization != null && !authorization.isBlank()) {
                    String sessionId = extractSessionId(authorization);
                    if (sessionId != null) {
                        log.debug("[SessionIdResolver] {} - Found Authorization header, sessionId: {}...", uri, sessionId.substring(0, Math.min(8, sessionId.length())));
                        return Collections.singletonList(sessionId);
                    }
                }

                log.debug("[SessionIdResolver] {} - No session ID found in headers", uri);
                return Collections.emptyList();
            }

            @Override
            public void setSessionId(HttpServletRequest request, HttpServletResponse response, String sessionId) {
                response.setHeader(SessionConstants.HEADER_TOKEN, sessionId);
            }

            @Override
            public void expireSession(HttpServletRequest request, HttpServletResponse response) {
                response.setHeader(SessionConstants.HEADER_TOKEN, "");
            }

            /**
             * 从 Authorization 请求头提取 Session ID
             * 支持格式：Bearer {sessionId} 或 Session {sessionId}
             */
            private String extractSessionId(String authorization) {
                if (authorization.startsWith(BEARER_PREFIX)) {
                    return authorization.substring(BEARER_PREFIX.length()).trim();
                }
                if (authorization.startsWith(SESSION_PREFIX)) {
                    return authorization.substring(SESSION_PREFIX.length()).trim();
                }
                return null;
            }
        };
    }
}
