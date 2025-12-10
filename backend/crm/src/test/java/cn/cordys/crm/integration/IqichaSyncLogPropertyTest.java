package cn.cordys.crm.integration;

import cn.cordys.crm.integration.domain.IqichaSyncLog;
import cn.cordys.crm.integration.service.IqichaSyncLogService;
import net.jqwik.api.*;
import net.jqwik.api.constraints.AlphaChars;
import net.jqwik.api.constraints.NumericChars;
import net.jqwik.api.constraints.StringLength;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 爱企查同步日志属性测试
 * 
 * **Feature: crm-mobile-enterprise-ai, Property 28: 操作日志完整性**
 * **Validates: Requirements 9.2**
 * 
 * @author cordys
 * @date 2025-12-10
 */
class IqichaSyncLogPropertyTest {

    private final IqichaSyncLogService syncLogService = new IqichaSyncLogService();

    /**
     * Property 28: 操作日志完整性
     * For any 爱企查服务调用，应该记录包含操作人、目标企业、操作类型、时间的日志
     * 
     * **Feature: crm-mobile-enterprise-ai, Property 28: 操作日志完整性**
     * **Validates: Requirements 9.2**
     */
    @Property(tries = 100)
    void logWithAllRequiredFieldsShouldBeComplete(
            @ForAll("validOperatorIds") String operatorId,
            @ForAll("validActions") String action,
            @ForAll("validTimestamps") Long createTime
    ) {
        // Given: 一个包含所有必填字段的日志记录
        IqichaSyncLog log = createLog(operatorId, action, createTime);

        // When: 验证日志完整性
        boolean isComplete = syncLogService.isLogComplete(log);

        // Then: 应该被识别为完整的日志
        assertThat(isComplete)
                .as("包含操作人(%s)、操作类型(%s)、时间(%d)的日志应该是完整的", 
                    operatorId, action, createTime)
                .isTrue();
    }

    /**
     * 缺少操作人的日志不应该被识别为完整
     * 
     * **Feature: crm-mobile-enterprise-ai, Property 28: 操作日志完整性**
     * **Validates: Requirements 9.2**
     */
    @Property(tries = 100)
    void logWithoutOperatorShouldNotBeComplete(
            @ForAll("validActions") String action,
            @ForAll("validTimestamps") Long createTime
    ) {
        // Given: 一个缺少操作人的日志记录
        IqichaSyncLog log = createLog(null, action, createTime);

        // When: 验证日志完整性
        boolean isComplete = syncLogService.isLogComplete(log);

        // Then: 不应该被识别为完整的日志
        assertThat(isComplete)
                .as("缺少操作人的日志不应该是完整的")
                .isFalse();
    }

    /**
     * 缺少操作类型的日志不应该被识别为完整
     * 
     * **Feature: crm-mobile-enterprise-ai, Property 28: 操作日志完整性**
     * **Validates: Requirements 9.2**
     */
    @Property(tries = 100)
    void logWithoutActionShouldNotBeComplete(
            @ForAll("validOperatorIds") String operatorId,
            @ForAll("validTimestamps") Long createTime
    ) {
        // Given: 一个缺少操作类型的日志记录
        IqichaSyncLog log = createLog(operatorId, null, createTime);

        // When: 验证日志完整性
        boolean isComplete = syncLogService.isLogComplete(log);

        // Then: 不应该被识别为完整的日志
        assertThat(isComplete)
                .as("缺少操作类型的日志不应该是完整的")
                .isFalse();
    }

    /**
     * 缺少时间的日志不应该被识别为完整
     * 
     * **Feature: crm-mobile-enterprise-ai, Property 28: 操作日志完整性**
     * **Validates: Requirements 9.2**
     */
    @Property(tries = 100)
    void logWithoutTimeShouldNotBeComplete(
            @ForAll("validOperatorIds") String operatorId,
            @ForAll("validActions") String action
    ) {
        // Given: 一个缺少时间的日志记录
        IqichaSyncLog log = createLog(operatorId, action, null);

        // When: 验证日志完整性
        boolean isComplete = syncLogService.isLogComplete(log);

        // Then: 不应该被识别为完整的日志
        assertThat(isComplete)
                .as("缺少时间的日志不应该是完整的")
                .isFalse();
    }

    /**
     * null日志不应该被识别为完整
     */
    @Example
    void nullLogShouldNotBeComplete() {
        assertThat(syncLogService.isLogComplete(null))
                .as("null日志不应该是完整的")
                .isFalse();
    }

    /**
     * 日志应该包含正确的操作类型
     * 
     * **Feature: crm-mobile-enterprise-ai, Property 28: 操作日志完整性**
     * **Validates: Requirements 9.2**
     */
    @Property(tries = 100)
    void logShouldPreserveActionType(
            @ForAll("validOperatorIds") String operatorId,
            @ForAll("validActions") String action,
            @ForAll("validTimestamps") Long createTime
    ) {
        // Given: 创建一个日志记录
        IqichaSyncLog log = createLog(operatorId, action, createTime);

        // Then: 日志应该保留正确的操作类型
        assertThat(log.getAction())
                .as("日志应该保留正确的操作类型")
                .isEqualTo(action);
    }

    /**
     * 日志应该包含正确的操作人
     * 
     * **Feature: crm-mobile-enterprise-ai, Property 28: 操作日志完整性**
     * **Validates: Requirements 9.2**
     */
    @Property(tries = 100)
    void logShouldPreserveOperatorId(
            @ForAll("validOperatorIds") String operatorId,
            @ForAll("validActions") String action,
            @ForAll("validTimestamps") Long createTime
    ) {
        // Given: 创建一个日志记录
        IqichaSyncLog log = createLog(operatorId, action, createTime);

        // Then: 日志应该保留正确的操作人
        assertThat(log.getOperatorId())
                .as("日志应该保留正确的操作人")
                .isEqualTo(operatorId);
    }

    /**
     * 日志应该包含正确的时间
     * 
     * **Feature: crm-mobile-enterprise-ai, Property 28: 操作日志完整性**
     * **Validates: Requirements 9.2**
     */
    @Property(tries = 100)
    void logShouldPreserveCreateTime(
            @ForAll("validOperatorIds") String operatorId,
            @ForAll("validActions") String action,
            @ForAll("validTimestamps") Long createTime
    ) {
        // Given: 创建一个日志记录
        IqichaSyncLog log = createLog(operatorId, action, createTime);

        // Then: 日志应该保留正确的时间
        assertThat(log.getCreateTime())
                .as("日志应该保留正确的时间")
                .isEqualTo(createTime);
    }

    // ==================== 数据生成器 ====================

    @Provide
    Arbitrary<String> validOperatorIds() {
        return Arbitraries.strings()
                .alpha()
                .numeric()
                .ofMinLength(10)
                .ofMaxLength(32);
    }

    @Provide
    Arbitrary<String> validActions() {
        return Arbitraries.of(
                IqichaSyncLogService.ACTION_IMPORT,
                IqichaSyncLogService.ACTION_SYNC,
                IqichaSyncLogService.ACTION_UPDATE,
                IqichaSyncLogService.ACTION_SEARCH
        );
    }

    @Provide
    Arbitrary<Long> validTimestamps() {
        // 生成2020年到2030年之间的时间戳
        long start = 1577836800000L; // 2020-01-01
        long end = 1893456000000L;   // 2030-01-01
        return Arbitraries.longs().between(start, end);
    }

    /**
     * 创建测试用日志记录
     */
    private IqichaSyncLog createLog(String operatorId, String action, Long createTime) {
        IqichaSyncLog log = new IqichaSyncLog();
        log.setOperatorId(operatorId);
        log.setAction(action);
        log.setCreateTime(createTime);
        return log;
    }
}
