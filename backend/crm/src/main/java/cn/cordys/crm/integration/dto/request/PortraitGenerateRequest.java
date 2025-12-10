package cn.cordys.crm.integration.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

/**
 * 画像生成请求 DTO
 * 
 * @author cordys
 * @date 2025-12-10
 */
@Data
public class PortraitGenerateRequest {

    @NotBlank(message = "客户ID不能为空")
    @Schema(description = "客户ID", required = true)
    private String customerId;

    @Schema(description = "是否强制刷新", defaultValue = "false")
    private Boolean forceRefresh = false;
}
