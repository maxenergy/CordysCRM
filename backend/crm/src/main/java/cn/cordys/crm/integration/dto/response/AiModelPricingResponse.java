package cn.cordys.crm.integration.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;

import java.math.BigDecimal;

/**
 * AI Model Pricing Response DTO
 * 
 * Requirements: 8.1, 8.2, 8.3
 * 
 * @author cordys
 * @date 2025-12-27
 */
@Data
@Schema(description = "AI Model Pricing Response")
public class AiModelPricingResponse {

    @Schema(description = "Pricing ID")
    private String id;

    @Schema(description = "Provider Code")
    private String providerCode;

    @Schema(description = "Model Code")
    private String modelCode;

    @Schema(description = "Input Price Per 1000 Tokens")
    private BigDecimal inputPrice;

    @Schema(description = "Output Price Per 1000 Tokens")
    private BigDecimal outputPrice;

    @Schema(description = "Currency")
    private String currency;

    @Schema(description = "Unit")
    private Integer unit;

    @Schema(description = "Is Active")
    private Boolean isActive;

    @Schema(description = "Create Time")
    private Long createTime;

    @Schema(description = "Update Time")
    private Long updateTime;

    @Schema(description = "Create User")
    private String createUser;

    @Schema(description = "Update User")
    private String updateUser;
}
