package cn.cordys.crm.integration.domain;

import cn.cordys.common.domain.BaseModel;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.persistence.Table;
import lombok.Data;

import java.math.BigDecimal;

/**
 * 企业工商信息
 *
 * @author cordys
 * @date 2025-12-10
 */
@Data
@Table(name = "enterprise_profile")
public class EnterpriseProfile extends BaseModel {

    @Schema(description = "客户ID")
    private String customerId;

    @Schema(description = "爱企查企业ID")
    private String iqichaId;

    @Schema(description = "统一社会信用代码")
    private String creditCode;

    @Schema(description = "企业名称")
    private String companyName;

    @Schema(description = "法定代表人")
    private String legalPerson;

    @Schema(description = "注册资本(万元)")
    private BigDecimal regCapital;

    @Schema(description = "成立日期")
    private Long regDate;

    @Schema(description = "人员规模")
    private String staffSize;

    @Schema(description = "行业代码")
    private String industryCode;

    @Schema(description = "行业名称")
    private String industryName;

    @Schema(description = "省份")
    private String province;

    @Schema(description = "城市")
    private String city;

    @Schema(description = "注册地址")
    private String address;

    @Schema(description = "经营状态")
    private String status;

    @Schema(description = "联系电话")
    private String phone;

    @Schema(description = "邮箱")
    private String email;

    @Schema(description = "官网")
    private String website;

    @Schema(description = "股东信息(JSON)")
    private String shareholders;

    @Schema(description = "高管信息(JSON)")
    private String executives;

    @Schema(description = "风险信息(JSON)")
    private String risks;

    @Schema(description = "数据来源")
    private String source;

    @Schema(description = "最后同步时间")
    private Long lastSyncAt;

    @Schema(description = "组织ID")
    private String organizationId;
}
