package cn.cordys.crm.integration;

import cn.cordys.crm.integration.domain.AIGenerationLog;
import cn.cordys.crm.integration.service.AIGenerationLogService;
import net.jqwik.api.*;
import net.jqwik.api.constraints.IntRange;
import net.jqwik.api.constraints.NotBlank;
import net.jqwik.api.constraints.StringLength;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Property-Based Tests for AI Generation Log Completeness
 * 
 * **Feature: crm-mobile-enterprise-ai, Property 19: AI调用日志完整性**
 * **Validates: Requirements 5.8**
 * 
 * For any AI service call, a log record should be created containing
 * model name, token consumption, latency, and status.
 */
public class AIGenerationLogPropertyTest {

    private final AIGenerationLogService logService = new AIGenerationLogService();

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 19: AI调用日志完整性**
     * **Validates: Requirements 5.8**
     * 
     * For any successful AI call, the log should contain all required fields.
     */
    @Property(tries = 100)
    void successfulCallLogIsComplete(
            @ForAll @NotBlank @StringLength(min = 1, max = 64) String model,
            @ForAll @IntRange(min = 1, max = 10000) int promptTokens,
            @ForAll @IntRange(min = 1, max = 5000) int completionTokens,
            @ForAll @IntRange(min = 100, max = 60000) int latencyMs
    ) {
        AIGenerationLog log = createSuccessLog(model, promptTokens, completionTokens, latencyMs);
        
        boolean isComplete = logService.validateLogCompleteness(log);
        
        assertThat(isComplete).isTrue();
        assertThat(log.getModel()).isEqualTo(model);
        assertThat(log.getTokensPrompt()).isEqualTo(promptTokens);
        assertThat(log.getTokensCompletion()).isEqualTo(completionTokens);
        assertThat(log.getLatencyMs()).isEqualTo(latencyMs);
        assertThat(log.getStatus()).isEqualTo("success");
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 19: AI调用日志完整性**
     * **Validates: Requirements 5.8**
     * 
     * For any failed AI call, the log should contain error information.
     */
    @Property(tries = 100)
    void failedCallLogContainsError(
            @ForAll @NotBlank @StringLength(min = 1, max = 64) String model,
            @ForAll @IntRange(min = 100, max = 60000) int latencyMs,
            @ForAll @NotBlank @StringLength(min = 1, max = 256) String errorMsg
    ) {
        AIGenerationLog log = createFailedLog(model, latencyMs, errorMsg);
        
        boolean isComplete = logService.validateLogCompleteness(log);
        
        assertThat(isComplete).isTrue();
        assertThat(log.getModel()).isEqualTo(model);
        assertThat(log.getLatencyMs()).isEqualTo(latencyMs);
        assertThat(log.getStatus()).isEqualTo("failed");
        assertThat(log.getErrorMsg()).isEqualTo(errorMsg);
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 19: AI调用日志完整性**
     * **Validates: Requirements 5.8**
     * 
     * Log without model name should be incomplete.
     */
    @Property(tries = 100)
    void logWithoutModelIsIncomplete(
            @ForAll @IntRange(min = 100, max = 60000) int latencyMs
    ) {
        AIGenerationLog log = new AIGenerationLog();
        log.setModel(null);
        log.setStatus("success");
        log.setLatencyMs(latencyMs);
        log.setTokensPrompt(100);
        log.setTokensCompletion(50);
        
        boolean isComplete = logService.validateLogCompleteness(log);
        
        assertThat(isComplete).isFalse();
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 19: AI调用日志完整性**
     * **Validates: Requirements 5.8**
     * 
     * Log without status should be incomplete.
     */
    @Property(tries = 100)
    void logWithoutStatusIsIncomplete(
            @ForAll @NotBlank @StringLength(min = 1, max = 64) String model,
            @ForAll @IntRange(min = 100, max = 60000) int latencyMs
    ) {
        AIGenerationLog log = new AIGenerationLog();
        log.setModel(model);
        log.setStatus(null);
        log.setLatencyMs(latencyMs);
        
        boolean isComplete = logService.validateLogCompleteness(log);
        
        assertThat(isComplete).isFalse();
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 19: AI调用日志完整性**
     * **Validates: Requirements 5.8**
     * 
     * Successful log without token info should be incomplete.
     */
    @Property(tries = 100)
    void successLogWithoutTokensIsIncomplete(
            @ForAll @NotBlank @StringLength(min = 1, max = 64) String model,
            @ForAll @IntRange(min = 100, max = 60000) int latencyMs
    ) {
        AIGenerationLog log = new AIGenerationLog();
        log.setModel(model);
        log.setStatus("success");
        log.setLatencyMs(latencyMs);
        log.setTokensPrompt(null);
        log.setTokensCompletion(null);
        
        boolean isComplete = logService.validateLogCompleteness(log);
        
        assertThat(isComplete).isFalse();
    }

    private AIGenerationLog createSuccessLog(String model, int promptTokens, int completionTokens, int latencyMs) {
        AIGenerationLog log = new AIGenerationLog();
        log.setId("test-id");
        log.setCustomerId("customer-1");
        log.setScene("portrait");
        log.setModel(model);
        log.setProvider("local");
        log.setTokensPrompt(promptTokens);
        log.setTokensCompletion(completionTokens);
        log.setLatencyMs(latencyMs);
        log.setStatus("success");
        log.setCost(BigDecimal.valueOf((promptTokens + completionTokens) * 0.00001));
        log.setCreateTime(System.currentTimeMillis());
        return log;
    }

    private AIGenerationLog createFailedLog(String model, int latencyMs, String errorMsg) {
        AIGenerationLog log = new AIGenerationLog();
        log.setId("test-id");
        log.setCustomerId("customer-1");
        log.setScene("portrait");
        log.setModel(model);
        log.setProvider("local");
        log.setLatencyMs(latencyMs);
        log.setStatus("failed");
        log.setErrorMsg(errorMsg);
        log.setCreateTime(System.currentTimeMillis());
        return log;
    }
}
