package cn.cordys.crm.integration.domain;

import cn.cordys.common.domain.BaseModel;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.persistence.Table;
import lombok.Data;

/**
 * AI企业画像
 *
 * @author cordys
 * @date 2025-12-10
 */
@Data
@Table(name = "company_portrait")
public class CompanyPortrait extends BaseModel {

    @Schema(description = "客户ID")
    private String customerId;

    @Schema(description = "画像数据(JSON)")
    private String portrait;

    @Schema(description = "商机洞察(JSON)")
    private String opportunities;

    @Schema(description = "风险提示(JSON)")
    private String risks;

    @Schema(description = "舆情信息(JSON)")
    private String publicOpinion;

    @Schema(description = "AI模型名称")
    private String model;

    @Schema(description = "画像版本")
    private String version;

    @Schema(description = "数据来源")
    private String source;

    @Schema(description = "生成时间")
    private Long generatedAt;

    @Schema(description = "组织ID")
    private String organizationId;
}
