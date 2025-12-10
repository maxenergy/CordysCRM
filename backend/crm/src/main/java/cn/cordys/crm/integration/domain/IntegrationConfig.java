package cn.cordys.crm.integration.domain;

import cn.cordys.common.domain.BaseModel;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.persistence.Table;
import lombok.Data;

/**
 * 集成配置
 *
 * @author cordys
 * @date 2025-12-10
 */
@Data
@Table(name = "integration_config")
public class IntegrationConfig extends BaseModel {

    @Schema(description = "配置键")
    private String configKey;

    @Schema(description = "配置值")
    private String configValue;

    @Schema(description = "是否加密")
    private Boolean encrypted;

    @Schema(description = "组织ID")
    private String organizationId;

    @Schema(description = "描述")
    private String description;
}
