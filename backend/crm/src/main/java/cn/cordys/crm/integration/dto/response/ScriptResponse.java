package cn.cordys.crm.integration.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 话术响应 DTO
 * 
 * @author cordys
 * @date 2025-12-10
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ScriptResponse {

    @Schema(description = "话术ID")
    private String scriptId;

    @Schema(description = "客户ID")
    private String customerId;

    @Schema(description = "话术内容")
    private String content;

    @Schema(description = "场景")
    private String scene;

    @Schema(description = "渠道")
    private String channel;

    @Schema(description = "语气")
    private String tone;

    @Schema(description = "AI模型")
    private String model;

    @Schema(description = "生成时间")
    private Long generatedAt;
}
