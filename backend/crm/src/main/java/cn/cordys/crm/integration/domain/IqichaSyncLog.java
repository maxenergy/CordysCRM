package cn.cordys.crm.integration.domain;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.persistence.Table;
import lombok.Data;

import java.io.Serial;
import java.io.Serializable;
import java.math.BigDecimal;

/**
 * 爱企查同步日志
 *
 * @author cordys
 * @date 2025-12-10
 */
@Data
@Table(name = "iqicha_sync_log")
public class IqichaSyncLog implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @Schema(description = "ID")
    private String id;

    @Schema(description = "操作人ID")
    private String operatorId;

    @Schema(description = "客户ID")
    private String customerId;

    @Schema(description = "爱企查企业ID")
    private String iqichaId;

    @Schema(description = "操作类型(import/sync/update)")
    private String action;

    @Schema(description = "请求参数(JSON)")
    private String requestParams;

    @Schema(description = "响应码")
    private Integer responseCode;

    @Schema(description = "响应消息")
    private String responseMsg;

    @Schema(description = "数据变更快照(JSON)")
    private String diffSnapshot;

    @Schema(description = "费用")
    private BigDecimal cost;

    @Schema(description = "组织ID")
    private String organizationId;

    @Schema(description = "创建时间")
    private Long createTime;
}
