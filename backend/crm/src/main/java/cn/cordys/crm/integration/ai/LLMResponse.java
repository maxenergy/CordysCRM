package cn.cordys.crm.integration.ai;

import lombok.Builder;
import lombok.Data;

/**
 * LLM 响应对象
 * 
 * @author cordys
 * @date 2025-12-10
 */
@Data
@Builder
public class LLMResponse {

    /**
     * 生成的内容
     */
    private String content;

    /**
     * 使用的模型
     */
    private String model;

    /**
     * Prompt Token 数
     */
    private Integer promptTokens;

    /**
     * 完成 Token 数
     */
    private Integer completionTokens;

    /**
     * 总 Token 数
     */
    public Integer getTotalTokens() {
        int prompt = promptTokens != null ? promptTokens : 0;
        int completion = completionTokens != null ? completionTokens : 0;
        return prompt + completion;
    }

    /**
     * 是否成功
     */
    @Builder.Default
    private boolean success = true;

    /**
     * 错误信息
     */
    private String errorMessage;

    /**
     * 创建失败响应
     */
    public static LLMResponse failure(String errorMessage) {
        return LLMResponse.builder()
                .success(false)
                .errorMessage(errorMessage)
                .build();
    }
}
