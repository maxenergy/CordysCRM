package cn.cordys.crm.integration.domain;

import cn.cordys.common.domain.BaseModel;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.persistence.Table;
import lombok.Data;

/**
 * 话术模板
 *
 * @author cordys
 * @date 2025-12-10
 */
@Data
@Table(name = "call_script_template")
public class CallScriptTemplate extends BaseModel {

    @Schema(description = "模板名称")
    private String name;

    @Schema(description = "适用行业")
    private String industry;

    @Schema(description = "场景(outreach/followup/renewal/meeting)")
    private String scene;

    @Schema(description = "渠道(phone/wechat/email)")
    private String channel;

    @Schema(description = "语言")
    private String language;

    @Schema(description = "语气(professional/enthusiastic/concise)")
    private String tone;

    @Schema(description = "模板内容")
    private String content;

    @Schema(description = "变量定义(JSON)")
    private String variables;

    @Schema(description = "版本")
    private String version;

    @Schema(description = "是否启用")
    private Boolean enabled;

    @Schema(description = "组织ID")
    private String organizationId;
}
