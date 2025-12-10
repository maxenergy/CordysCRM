package cn.cordys.crm.integration.ai;

import lombok.Builder;
import lombok.Data;

/**
 * LLM 请求对象
 * 
 * @author cordys
 * @date 2025-12-10
 */
@Data
@Builder
public class LLMRequest {

    /**
     * 模型名称
     */
    private String model;

    /**
     * 提示词
     */
    private String prompt;

    /**
     * 系统提示词
     */
    private String systemPrompt;

    /**
     * 温度参数 (0-1)
     */
    @Builder.Default
    private Double temperature = 0.7;

    /**
     * 最大 Token 数
     */
    @Builder.Default
    private Integer maxTokens = 2000;

    /**
     * 请求超时时间(毫秒)
     */
    @Builder.Default
    private Integer timeoutMs = 60000;
}
