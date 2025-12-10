package cn.cordys.crm.integration.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * API 限流服务
 * 基于滑动窗口的限流实现
 * 
 * Requirements: 8.6
 * 
 * @author cordys
 * @date 2025-12-10
 */
@Service
public class RateLimitService {

    private static final Logger log = LoggerFactory.getLogger(RateLimitService.class);

    /**
     * 用户级限流计数器: userId -> (windowStart, count)
     */
    private final Map<String, RateLimitWindow> userLimits = new ConcurrentHashMap<>();

    /**
     * 全局限流计数器
     */
    private final RateLimitWindow globalLimit = new RateLimitWindow();

    @Value("${ai.rate-limit.user-per-minute:10}")
    private int userLimitPerMinute;

    @Value("${ai.rate-limit.global-per-minute:100}")
    private int globalLimitPerMinute;

    @Value("${ai.rate-limit.window-size-ms:60000}")
    private long windowSizeMs;

    /**
     * 检查是否允许请求
     * 
     * Property 27: API限流有效性
     * For any 超过配置限额的 API 调用请求，应该被拒绝并返回限流错误
     * 
     * @param userId 用户ID
     * @return 是否允许
     */
    public boolean isAllowed(String userId) {
        long now = System.currentTimeMillis();
        
        // 检查全局限流
        if (!checkAndIncrement(globalLimit, globalLimitPerMinute, now)) {
            log.warn("Global rate limit exceeded");
            return false;
        }
        
        // 检查用户级限流
        RateLimitWindow userWindow = userLimits.computeIfAbsent(userId, k -> new RateLimitWindow());
        if (!checkAndIncrement(userWindow, userLimitPerMinute, now)) {
            log.warn("User rate limit exceeded for user: {}", userId);
            // 回滚全局计数
            globalLimit.decrement();
            return false;
        }
        
        return true;
    }

    /**
     * 检查限流并增加计数
     * 
     * @param window 限流窗口
     * @param limit 限制数量
     * @param now 当前时间
     * @return 是否允许
     */
    private boolean checkAndIncrement(RateLimitWindow window, int limit, long now) {
        synchronized (window) {
            // 检查是否需要重置窗口
            if (now - window.windowStart > windowSizeMs) {
                window.reset(now);
            }
            
            // 检查是否超过限制
            if (window.count.get() >= limit) {
                return false;
            }
            
            // 增加计数
            window.count.incrementAndGet();
            return true;
        }
    }

    /**
     * 获取用户剩余配额
     * 
     * @param userId 用户ID
     * @return 剩余配额
     */
    public int getRemainingQuota(String userId) {
        long now = System.currentTimeMillis();
        RateLimitWindow userWindow = userLimits.get(userId);
        
        if (userWindow == null) {
            return userLimitPerMinute;
        }
        
        synchronized (userWindow) {
            if (now - userWindow.windowStart > windowSizeMs) {
                return userLimitPerMinute;
            }
            return Math.max(0, userLimitPerMinute - userWindow.count.get());
        }
    }

    /**
     * 获取全局剩余配额
     * 
     * @return 剩余配额
     */
    public int getGlobalRemainingQuota() {
        long now = System.currentTimeMillis();
        
        synchronized (globalLimit) {
            if (now - globalLimit.windowStart > windowSizeMs) {
                return globalLimitPerMinute;
            }
            return Math.max(0, globalLimitPerMinute - globalLimit.count.get());
        }
    }

    /**
     * 重置用户限流
     * 
     * @param userId 用户ID
     */
    public void resetUserLimit(String userId) {
        userLimits.remove(userId);
    }

    /**
     * 重置全局限流
     */
    public void resetGlobalLimit() {
        globalLimit.reset(System.currentTimeMillis());
    }

    /**
     * 设置用户限流配置（用于测试）
     */
    public void setUserLimitPerMinute(int limit) {
        this.userLimitPerMinute = limit;
    }

    /**
     * 设置全局限流配置（用于测试）
     */
    public void setGlobalLimitPerMinute(int limit) {
        this.globalLimitPerMinute = limit;
    }

    /**
     * 设置窗口大小（用于测试）
     */
    public void setWindowSizeMs(long windowSizeMs) {
        this.windowSizeMs = windowSizeMs;
    }

    /**
     * 限流窗口
     */
    private static class RateLimitWindow {
        volatile long windowStart = System.currentTimeMillis();
        final AtomicInteger count = new AtomicInteger(0);

        void reset(long now) {
            windowStart = now;
            count.set(0);
        }

        void decrement() {
            count.decrementAndGet();
        }
    }
}
