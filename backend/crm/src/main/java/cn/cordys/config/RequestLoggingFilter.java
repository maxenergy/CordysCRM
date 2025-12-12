package cn.cordys.config;

import jakarta.servlet.*;
import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.util.Collections;
import java.util.Enumeration;

/**
 * 请求日志过滤器 - 用于调试请求路由问题
 * 打印所有进入后端的HTTP请求详情
 */
@Slf4j
@Component
@Order(1)
public class RequestLoggingFilter implements Filter {

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        
        HttpServletRequest httpRequest = (HttpServletRequest) request;
        
        String method = httpRequest.getMethod();
        String uri = httpRequest.getRequestURI();
        String queryString = httpRequest.getQueryString();
        String contentType = httpRequest.getContentType();
        
        // 打印请求基本信息
        log.info("========== 收到HTTP请求 ==========");
        log.info("Method: {}", method);
        log.info("URI: {}", uri);
        log.info("QueryString: {}", queryString);
        log.info("ContentType: {}", contentType);
        log.info("RemoteAddr: {}", httpRequest.getRemoteAddr());
        
        // 打印请求头
        StringBuilder headers = new StringBuilder();
        Enumeration<String> headerNames = httpRequest.getHeaderNames();
        while (headerNames.hasMoreElements()) {
            String headerName = headerNames.nextElement();
            String headerValue = httpRequest.getHeader(headerName);
            headers.append(headerName).append(": ").append(headerValue).append("; ");
        }
        log.info("Headers: {}", headers);
        
        // 特别检查是否是 /api/enterprise/config/cookie 请求
        if (uri.contains("/enterprise/config/cookie")) {
            log.info(">>>>>> 检测到爱企查Cookie保存请求! <<<<<<");
        }
        
        log.info("==================================");
        
        chain.doFilter(request, response);
    }
}
