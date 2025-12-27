package cn.cordys.crm.integration.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.Data;

import java.math.BigDecimal;

/**
 * AI Model Pricing Request DTO
 * 
 * Requirements: 8.1, 8.2, 8.3
 * 
 * @author cordys
 * @date 2025-12-27
 */
@Data
@Schema(description = "AI Model Pricing Request")
public class AiModelPricingRequest {

    @Schema(description = "Provider Code (openai, aliyun, claude)")
    @NotBlank(message = "Provider code cannot be blank")
    private String providerCode;

    @Schema(description = "Model Code (gpt-4, gpt-3.5-turbo, qwen-max)")
    @NotBlank(message = "Model code cannot be blank")
    private String modelCode;

    @Schema(description = "Input Price Per 1000 Tokens")
    @NotNull(message = "Input price cannot be null")
    @Positive(message = "Input price must be positive")
    private BigDecimal inputPrice;

    @Schema(description = "Output Price Per 1000 Tokens")
    @NotNull(message = "Output price cannot be null")
    @Positive(message = "Output price must be positive")
    private BigDecimal outputPrice;

    @Schema(description = "Currency (USD, CNY)")
    @NotBlank(message = "Currency cannot be blank")
    private String currency;

    @Schema(description = "Unit (default 1000 tokens)")
    private Integer unit;

    @Schema(description = "Is Active")
    private Boolean isActive;
}
