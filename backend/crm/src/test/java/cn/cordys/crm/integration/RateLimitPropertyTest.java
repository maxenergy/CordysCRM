package cn.cordys.crm.integration;

import cn.cordys.crm.integration.service.RateLimitService;
import net.jqwik.api.*;
import net.jqwik.api.constraints.IntRange;
import net.jqwik.api.constraints.NotBlank;
import net.jqwik.api.constraints.StringLength;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Property-Based Tests for API Rate Limiting
 * 
 * **Feature: crm-mobile-enterprise-ai, Property 27: API限流有效性**
 * **Validates: Requirements 8.6**
 * 
 * For any API call requests exceeding the configured limit,
 * they should be rejected with a rate limit error.
 */
public class RateLimitPropertyTest {

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 27: API限流有效性**
     * **Validates: Requirements 8.6**
     * 
     * Requests within limit should be allowed.
     */
    @Property(tries = 100)
    void requestsWithinLimitAreAllowed(
            @ForAll @NotBlank @StringLength(min = 1, max = 32) String userId,
            @ForAll @IntRange(min = 1, max = 10) int requestCount
    ) {
        RateLimitService service = new RateLimitService();
        service.setUserLimitPerMinute(10);
        service.setGlobalLimitPerMinute(100);
        service.setWindowSizeMs(60000);
        
        // Make requests within limit
        int allowedCount = 0;
        for (int i = 0; i < requestCount; i++) {
            if (service.isAllowed(userId)) {
                allowedCount++;
            }
        }
        
        // All requests should be allowed
        assertThat(allowedCount).isEqualTo(requestCount);
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 27: API限流有效性**
     * **Validates: Requirements 8.6**
     * 
     * Requests exceeding user limit should be rejected.
     */
    @Property(tries = 100)
    void requestsExceedingUserLimitAreRejected(
            @ForAll @NotBlank @StringLength(min = 1, max = 32) String userId,
            @ForAll @IntRange(min = 1, max = 5) int limit
    ) {
        RateLimitService service = new RateLimitService();
        service.setUserLimitPerMinute(limit);
        service.setGlobalLimitPerMinute(100);
        service.setWindowSizeMs(60000);
        
        // Make requests up to limit
        for (int i = 0; i < limit; i++) {
            assertThat(service.isAllowed(userId)).isTrue();
        }
        
        // Next request should be rejected
        assertThat(service.isAllowed(userId)).isFalse();
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 27: API限流有效性**
     * **Validates: Requirements 8.6**
     * 
     * Different users should have independent limits.
     */
    @Property(tries = 100)
    void differentUsersHaveIndependentLimits(
            @ForAll @NotBlank @StringLength(min = 1, max = 32) String userId1,
            @ForAll @NotBlank @StringLength(min = 1, max = 32) String userId2
    ) {
        // Skip if same user
        if (userId1.equals(userId2)) {
            return;
        }
        
        RateLimitService service = new RateLimitService();
        service.setUserLimitPerMinute(5);
        service.setGlobalLimitPerMinute(100);
        service.setWindowSizeMs(60000);
        
        // Exhaust user1's limit
        for (int i = 0; i < 5; i++) {
            service.isAllowed(userId1);
        }
        
        // User2 should still be allowed
        assertThat(service.isAllowed(userId2)).isTrue();
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 27: API限流有效性**
     * **Validates: Requirements 8.6**
     * 
     * Remaining quota should decrease with each request.
     */
    @Property(tries = 100)
    void remainingQuotaDecreasesWithRequests(
            @ForAll @NotBlank @StringLength(min = 1, max = 32) String userId,
            @ForAll @IntRange(min = 1, max = 5) int requestCount
    ) {
        RateLimitService service = new RateLimitService();
        service.setUserLimitPerMinute(10);
        service.setGlobalLimitPerMinute(100);
        service.setWindowSizeMs(60000);
        
        int initialQuota = service.getRemainingQuota(userId);
        
        // Make requests
        for (int i = 0; i < requestCount; i++) {
            service.isAllowed(userId);
        }
        
        int remainingQuota = service.getRemainingQuota(userId);
        
        // Quota should decrease
        assertThat(remainingQuota).isEqualTo(initialQuota - requestCount);
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 27: API限流有效性**
     * **Validates: Requirements 8.6**
     * 
     * Reset should restore full quota.
     */
    @Property(tries = 100)
    void resetRestoresFullQuota(
            @ForAll @NotBlank @StringLength(min = 1, max = 32) String userId,
            @ForAll @IntRange(min = 1, max = 5) int requestCount
    ) {
        RateLimitService service = new RateLimitService();
        int limit = 10;
        service.setUserLimitPerMinute(limit);
        service.setGlobalLimitPerMinute(100);
        service.setWindowSizeMs(60000);
        
        // Make some requests
        for (int i = 0; i < requestCount; i++) {
            service.isAllowed(userId);
        }
        
        // Reset
        service.resetUserLimit(userId);
        
        // Quota should be restored
        assertThat(service.getRemainingQuota(userId)).isEqualTo(limit);
    }
}
