package cn.cordys.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.session.data.redis.RedisIndexedSessionRepository;

/**
 * 配置 UserCurrentBypassFilter，以最高优先级注册。
 * 确保在 Shiro 之前处理 /api/user/current 请求。
 * 
 * 注意：Shiro 的 ShiroFilterFactoryBean 默认注册顺序是 Integer.MAX_VALUE - 1，
 * 我们需要使用更低的值（如 Integer.MIN_VALUE + 1）来确保在 Shiro 之前执行。
 */
@Configuration
public class UserCurrentBypassFilterConfig {

    private static final Logger log = LoggerFactory.getLogger(UserCurrentBypassFilterConfig.class);

    /**
     * 注册 UserCurrentBypassFilter，使用最高优先级。
     * 
     * Spring Session 的 SessionRepositoryFilter 使用 Integer.MIN_VALUE + 50，
     * 我们使用 Integer.MIN_VALUE + 1 来确保在 Session 过滤器之后、Shiro 之前执行。
     */
    @Bean
    public FilterRegistrationBean<UserCurrentBypassFilter> userCurrentBypassFilter(
            RedisIndexedSessionRepository sessionRepository,
            ObjectMapper objectMapper
    ) {
        log.info("========== Registering UserCurrentBypassFilter ==========");
        
        FilterRegistrationBean<UserCurrentBypassFilter> registration = new FilterRegistrationBean<>();
        registration.setName("userCurrentBypassFilter");
        registration.setFilter(new UserCurrentBypassFilter(sessionRepository, objectMapper));
        registration.addUrlPatterns("/api/user/current", "/api/user/current/*");
        // 使用比 Spring Session (MIN_VALUE + 50) 更高但比 Shiro 更低的优先级
        // Shiro 默认使用 Integer.MAX_VALUE - 1
        registration.setOrder(Integer.MIN_VALUE + 100);
        
        log.info("UserCurrentBypassFilter registered with order: {}", Integer.MIN_VALUE + 100);
        log.info("URL patterns: /api/user/current, /api/user/current/*");
        log.info("==========================================================");
        
        return registration;
    }
}
