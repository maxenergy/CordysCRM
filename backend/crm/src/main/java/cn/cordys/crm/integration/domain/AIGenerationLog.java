package cn.cordys.crm.integration.domain;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.persistence.Table;
import lombok.Data;

import java.io.Serial;
import java.io.Serializable;
import java.math.BigDecimal;

/**
 * AI生成日志
 *
 * @author cordys
 * @date 2025-12-10
 */
@Data
@Table(name = "ai_generation_log")
public class AIGenerationLog implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @Schema(description = "ID")
    private String id;

    @Schema(description = "客户ID")
    private String customerId;

    @Schema(description = "场景(portrait/script)")
    private String scene;

    @Schema(description = "AI模型名称")
    private String model;

    @Schema(description = "提供商(openai/claude/local)")
    private String provider;

    @Schema(description = "Prompt哈希")
    private String promptHash;

    @Schema(description = "Prompt Token数")
    private Integer tokensPrompt;

    @Schema(description = "完成 Token数")
    private Integer tokensCompletion;

    @Schema(description = "耗时(毫秒)")
    private Integer latencyMs;

    @Schema(description = "状态(success/failed/timeout)")
    private String status;

    @Schema(description = "错误信息")
    private String errorMsg;

    @Schema(description = "费用")
    private BigDecimal cost;

    @Schema(description = "组织ID")
    private String organizationId;

    @Schema(description = "创建时间")
    private Long createTime;

    @Schema(description = "创建人")
    private String createUser;
}
