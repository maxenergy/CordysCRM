package cn.cordys.crm.integration.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

/**
 * 话术生成请求 DTO
 * 
 * @author cordys
 * @date 2025-12-10
 */
@Data
public class ScriptGenerateRequest {

    @NotBlank(message = "客户ID不能为空")
    @Schema(description = "客户ID", required = true)
    private String customerId;

    @NotBlank(message = "场景不能为空")
    @Schema(description = "场景(outreach/followup/renewal/meeting)", required = true)
    private String scene;

    @Schema(description = "渠道(phone/wechat/email)", defaultValue = "phone")
    private String channel = "phone";

    @Schema(description = "语气(professional/enthusiastic/concise)", defaultValue = "professional")
    private String tone = "professional";

    @Schema(description = "模板ID(可选)")
    private String templateId;

    @Schema(description = "商机ID(可选)")
    private String opportunityId;
}
