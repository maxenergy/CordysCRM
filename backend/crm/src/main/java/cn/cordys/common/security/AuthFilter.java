package cn.cordys.common.security;

import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.apache.shiro.SecurityUtils;
import org.apache.shiro.web.filter.authc.FormAuthenticationFilter;
import org.apache.shiro.web.util.WebUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * @Author: jianxing
 * @CreateTime: 2025-04-23  10:47
 */
public class AuthFilter extends FormAuthenticationFilter {

    private static final Logger log = LoggerFactory.getLogger(AuthFilter.class);

    @Override
    protected boolean isAccessAllowed(ServletRequest request, ServletResponse response, Object mappedValue) {
        HttpServletRequest httpRequest = WebUtils.toHttp(request);
        String uri = httpRequest.getRequestURI();

        // 允许 CORS 预检请求通过：Chrome 扩展带 Authorization 头会先发 OPTIONS
        // 若这里返回 401，浏览器不会再发送真正的 GET/POST
        if ("OPTIONS".equalsIgnoreCase(httpRequest.getMethod())) {
            log.info("[AuthFilter] Allowing OPTIONS preflight request for: {}", uri);
            return true;
        }

        // 允许 /api/user/current 路径通过，由 Controller 自行处理认证
        // 这是为了支持 Chrome 扩展等外部客户端使用 Bearer token 认证
        if (uri.startsWith("/api/user/current")) {
            log.info("[AuthFilter] Allowing /api/user/current to pass through for manual auth");
            return true;
        }

        boolean authenticated = SecurityUtils.getSubject().isAuthenticated();
        log.info("[AuthFilter] isAccessAllowed for: {} {}, authenticated: {}", 
                httpRequest.getMethod(), uri, authenticated);
        return authenticated;
    }

    /**
     * 重写 onAccessDenied 方法，避免认证失败返回 302 重定向
     * 没有认证返回 401 状态码
     *
     * @param request
     * @param response
     *
     * @return
     *
     * @throws Exception
     */
    @Override
    protected boolean onAccessDenied(ServletRequest request, ServletResponse response) throws Exception {
        HttpServletRequest httpRequest = WebUtils.toHttp(request);
        log.info("[AuthFilter] onAccessDenied for: {}", httpRequest.getRequestURI());
        
        if (isLoginRequest(request, response)) {
            if (isLoginSubmission(request, response)) {
                return executeLogin(request, response);
            } else {
                return true;
            }
        } else {
            // 没有登入返回 401
            HttpServletResponse httpResponse = (HttpServletResponse) response;
            httpResponse.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
            httpResponse.setContentType("application/json;charset=UTF-8");
            return false;
        }
    }
}