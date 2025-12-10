package cn.cordys.crm.integration.ai;

/**
 * LLM 提供商接口
 * 支持多种 AI 提供商的抽象接口
 * 
 * Requirements: 5.4, 5.5
 * 
 * @author cordys
 * @date 2025-12-10
 */
public interface LLMProvider {

    /**
     * 获取提供商类型
     * 
     * @return 提供商类型
     */
    ProviderType getProviderType();

    /**
     * 生成 AI 响应
     * 
     * @param request LLM 请求
     * @return LLM 响应
     */
    LLMResponse generate(LLMRequest request);

    /**
     * 检查提供商是否可用
     * 
     * @return 是否可用
     */
    default boolean isAvailable() {
        return true;
    }
}
