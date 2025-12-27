package cn.cordys.crm.integration.domain;

import lombok.Data;

import java.math.BigDecimal;
import java.math.RoundingMode;

/**
 * AI模型定价配置
 * 
 * Requirements: 1.1, 1.4, 2.1, 2.2, 2.4
 * 
 * @author cordys
 * @date 2025-12-27
 */
@Data
public class AiModelPricing {
    
    /**
     * 主键ID
     */
    private String id;
    
    /**
     * 提供商代码 (openai/aliyun/claude)
     */
    private String providerCode;
    
    /**
     * 模型代码 (gpt-4/qwen-max)
     */
    private String modelCode;
    
    /**
     * 模型显示名称
     */
    private String modelName;
    
    /**
     * 输入Token价格
     */
    private BigDecimal inputPrice;
    
    /**
     * 输出Token价格
     */
    private BigDecimal outputPrice;
    
    /**
     * 计价单位 (默认1000 tokens)
     */
    private Integer unit;
    
    /**
     * 货币单位 (USD/CNY)
     */
    private String currency;
    
    /**
     * 是否启用
     */
    private Boolean enabled;
    
    /**
     * 描述
     */
    private String description;
    
    /**
     * 创建时间
     */
    private Long createTime;
    
    /**
     * 更新时间
     */
    private Long updateTime;
    
    /**
     * 创建人
     */
    private String createUser;
    
    /**
     * 更新人
     */
    private String updateUser;
    
    /**
     * 获取缓存键
     * 
     * @return 缓存键 (格式: provider:model)
     */
    public String getCacheKey() {
        return providerCode + ":" + modelCode;
    }
    
    /**
     * 计算成本
     * 
     * Property 2: Cost Calculation Accuracy
     * For any inputTokens, outputTokens, inputPrice, outputPrice:
     * cost = (inputTokens * inputPrice / unit) + (outputTokens * outputPrice / unit)
     * 
     * Requirements: 2.2, 2.4
     * 
     * @param inputTokens 输入Token数量
     * @param outputTokens 输出Token数量
     * @return 成本 (保留6位小数)
     */
    public BigDecimal calculateCost(int inputTokens, int outputTokens) {
        if (inputTokens < 0 || outputTokens < 0) {
            throw new IllegalArgumentException("Token counts cannot be negative");
        }
        
        if (inputPrice == null || outputPrice == null) {
            throw new IllegalStateException("Pricing not configured");
        }
        
        if (unit == null || unit <= 0) {
            throw new IllegalStateException("Invalid pricing unit");
        }
        
        // 计算输入成本: (inputTokens * inputPrice / unit)
        BigDecimal inputCost = BigDecimal.valueOf(inputTokens)
                .multiply(inputPrice)
                .divide(BigDecimal.valueOf(unit), 6, RoundingMode.HALF_UP);
        
        // 计算输出成本: (outputTokens * outputPrice / unit)
        BigDecimal outputCost = BigDecimal.valueOf(outputTokens)
                .multiply(outputPrice)
                .divide(BigDecimal.valueOf(unit), 6, RoundingMode.HALF_UP);
        
        // 总成本
        return inputCost.add(outputCost);
    }
}
