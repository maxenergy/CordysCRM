package cn.cordys.crm.integration.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * 企业信息导入响应
 * 
 * Requirements: 2.5, 2.6
 * 
 * @author cordys
 * @date 2025-12-10
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Schema(description = "企业信息导入响应")
public class EnterpriseImportResponse {

    @Schema(description = "是否成功")
    private Boolean success;

    @Schema(description = "创建或更新的客户ID")
    private String customerId;

    @Schema(description = "企业档案ID")
    private String enterpriseProfileId;

    @Schema(description = "是否新建客户")
    private Boolean isNew;

    @Schema(description = "冲突字段列表")
    private List<FieldConflict> conflicts;

    @Schema(description = "提示消息")
    private String message;

    /**
     * 字段冲突信息
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    @Schema(description = "字段冲突信息")
    public static class FieldConflict {

        @Schema(description = "字段名称")
        private String field;

        @Schema(description = "字段显示名称")
        private String fieldLabel;

        @Schema(description = "本地值(CRM中已有的值)")
        private String localValue;

        @Schema(description = "远程值(导入的新值)")
        private String remoteValue;
    }

    /**
     * 创建成功响应(新建)
     */
    public static EnterpriseImportResponse successNew(String customerId, String enterpriseProfileId) {
        return EnterpriseImportResponse.builder()
                .success(true)
                .customerId(customerId)
                .enterpriseProfileId(enterpriseProfileId)
                .isNew(true)
                .message("企业信息导入成功，已创建新客户")
                .build();
    }

    /**
     * 创建成功响应(更新)
     */
    public static EnterpriseImportResponse successUpdate(String customerId, String enterpriseProfileId) {
        return EnterpriseImportResponse.builder()
                .success(true)
                .customerId(customerId)
                .enterpriseProfileId(enterpriseProfileId)
                .isNew(false)
                .message("企业信息导入成功，已更新现有客户")
                .build();
    }

    /**
     * 创建冲突响应
     */
    public static EnterpriseImportResponse conflict(String customerId, List<FieldConflict> conflicts) {
        return EnterpriseImportResponse.builder()
                .success(false)
                .customerId(customerId)
                .isNew(false)
                .conflicts(conflicts)
                .message("检测到数据冲突，请选择处理方式")
                .build();
    }

    /**
     * 创建失败响应
     */
    public static EnterpriseImportResponse failure(String message) {
        return EnterpriseImportResponse.builder()
                .success(false)
                .message(message)
                .build();
    }
}
