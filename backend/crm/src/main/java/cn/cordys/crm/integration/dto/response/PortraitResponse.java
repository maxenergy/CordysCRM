package cn.cordys.crm.integration.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * 企业画像响应 DTO
 * 
 * @author cordys
 * @date 2025-12-10
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PortraitResponse {

    @Schema(description = "客户ID")
    private String customerId;

    @Schema(description = "画像数据")
    private Portrait portrait;

    @Schema(description = "生成时间")
    private Long generatedAt;

    @Schema(description = "AI模型")
    private String model;

    @Schema(description = "版本")
    private String version;

    /**
     * 画像数据结构
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Portrait {
        @Schema(description = "基本信息")
        private Basics basics;

        @Schema(description = "商机洞察")
        private List<Opportunity> opportunities;

        @Schema(description = "风险提示")
        private List<Risk> risks;

        @Schema(description = "舆情信息")
        private List<Sentiment> sentiments;
    }

    /**
     * 基本信息
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Basics {
        @Schema(description = "行业")
        private String industry;

        @Schema(description = "规模")
        private String scale;

        @Schema(description = "主营产品/服务")
        private String mainProducts;
    }

    /**
     * 商机洞察
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Opportunity {
        @Schema(description = "标题")
        private String title;

        @Schema(description = "置信度")
        private Double confidence;

        @Schema(description = "来源")
        private String source;
    }

    /**
     * 风险提示
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Risk {
        @Schema(description = "风险等级(高/中/低)")
        private String level;

        @Schema(description = "风险描述")
        private String text;
    }

    /**
     * 舆情信息
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Sentiment {
        @Schema(description = "标题")
        private String title;

        @Schema(description = "来源")
        private String source;

        @Schema(description = "情感倾向(正面/中性/负面)")
        private String sentiment;
    }
}
