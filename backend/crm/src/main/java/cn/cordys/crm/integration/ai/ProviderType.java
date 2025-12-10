package cn.cordys.crm.integration.ai;

/**
 * AI 提供商类型枚举
 * 
 * @author cordys
 * @date 2025-12-10
 */
public enum ProviderType {
    
    /**
     * OpenAI (GPT系列)
     */
    OPENAI("openai"),
    
    /**
     * Anthropic Claude
     */
    CLAUDE("claude"),
    
    /**
     * 本地部署模型
     */
    LOCAL("local"),
    
    /**
     * MaxKB 智能体
     */
    MAXKB("maxkb");

    private final String code;

    ProviderType(String code) {
        this.code = code;
    }

    public String getCode() {
        return code;
    }

    public static ProviderType fromCode(String code) {
        for (ProviderType type : values()) {
            if (type.code.equalsIgnoreCase(code)) {
                return type;
            }
        }
        throw new IllegalArgumentException("Unknown provider type: " + code);
    }
}
