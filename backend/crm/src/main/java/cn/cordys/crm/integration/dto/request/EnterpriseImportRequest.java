package cn.cordys.crm.integration.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.math.BigDecimal;

/**
 * 企业信息导入请求
 * 
 * Requirements: 2.3, 2.4
 * 
 * @author cordys
 * @date 2025-12-10
 */
@Data
@Schema(description = "企业信息导入请求")
public class EnterpriseImportRequest {

    @NotBlank(message = "企业名称不能为空")
    @Size(max = 256, message = "企业名称长度不能超过256个字符")
    @Schema(description = "企业名称", requiredMode = Schema.RequiredMode.REQUIRED)
    private String companyName;

    @NotBlank(message = "统一社会信用代码不能为空")
    @Size(min = 18, max = 18, message = "统一社会信用代码必须为18位")
    @Schema(description = "统一社会信用代码", requiredMode = Schema.RequiredMode.REQUIRED)
    private String creditCode;

    @Size(max = 128, message = "法定代表人长度不能超过128个字符")
    @Schema(description = "法定代表人")
    private String legalPerson;

    @Schema(description = "注册资本(万元)")
    private BigDecimal registeredCapital;

    @Schema(description = "成立日期(时间戳)")
    private Long establishmentDate;

    @Size(max = 512, message = "注册地址长度不能超过512个字符")
    @Schema(description = "注册地址")
    private String address;

    @Size(max = 64, message = "省份长度不能超过64个字符")
    @Schema(description = "省份")
    private String province;

    @Size(max = 64, message = "城市长度不能超过64个字符")
    @Schema(description = "城市")
    private String city;

    @Size(max = 128, message = "行业名称长度不能超过128个字符")
    @Schema(description = "行业名称")
    private String industry;

    @Size(max = 32, message = "行业代码长度不能超过32个字符")
    @Schema(description = "行业代码")
    private String industryCode;

    @Size(max = 64, message = "人员规模长度不能超过64个字符")
    @Schema(description = "人员规模")
    private String staffSize;

    @Size(max = 64, message = "联系电话长度不能超过64个字符")
    @Schema(description = "联系电话")
    private String phone;

    @Size(max = 128, message = "邮箱长度不能超过128个字符")
    @Schema(description = "邮箱")
    private String email;

    @Size(max = 256, message = "官网长度不能超过256个字符")
    @Schema(description = "官网")
    private String website;

    @Size(max = 64, message = "经营状态长度不能超过64个字符")
    @Schema(description = "经营状态")
    private String status;

    @Size(max = 64, message = "爱企查企业ID长度不能超过64个字符")
    @Schema(description = "爱企查企业ID")
    private String iqichaId;

    @Schema(description = "关联的客户ID(可选，如果提供则关联到现有客户)")
    private String customerId;

    @Size(max = 32, message = "来源长度不能超过32个字符")
    @Schema(description = "数据来源: chrome_extension/webview/manual")
    private String source;

    @Schema(description = "股东信息(JSON字符串)")
    private String shareholders;

    @Schema(description = "高管信息(JSON字符串)")
    private String executives;

    @Schema(description = "风险信息(JSON字符串)")
    private String risks;
}
