package cn.cordys.crm.integration.domain;

import cn.cordys.common.domain.BaseModel;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.persistence.Table;
import lombok.Data;

/**
 * 话术记录
 *
 * @author cordys
 * @date 2025-12-10
 */
@Data
@Table(name = "call_script")
public class CallScript extends BaseModel {

    @Schema(description = "客户ID")
    private String customerId;

    @Schema(description = "商机ID")
    private String opportunityId;

    @Schema(description = "模板ID")
    private String templateId;

    @Schema(description = "场景")
    private String scene;

    @Schema(description = "渠道(phone/wechat/email)")
    private String channel;

    @Schema(description = "语言")
    private String language;

    @Schema(description = "语气(professional/enthusiastic/concise)")
    private String tone;

    @Schema(description = "标签(JSON)")
    private String tags;

    @Schema(description = "话术内容")
    private String content;

    @Schema(description = "AI模型名称")
    private String model;

    @Schema(description = "生成时间")
    private Long generatedAt;

    @Schema(description = "组织ID")
    private String organizationId;
}
