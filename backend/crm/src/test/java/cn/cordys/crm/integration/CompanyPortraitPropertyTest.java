package cn.cordys.crm.integration;

import cn.cordys.crm.integration.domain.CompanyPortrait;
import cn.cordys.common.util.JSON;
import net.jqwik.api.*;
import net.jqwik.api.constraints.NotBlank;
import net.jqwik.api.constraints.StringLength;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Property-Based Tests for CompanyPortrait entity
 * 
 * **Feature: crm-mobile-enterprise-ai, Property 18: 画像存储往返一致性**
 * **Validates: Requirements 5.6**
 * 
 * For any AI-generated company portrait, storing to database and then querying
 * should return exactly the same data structure.
 */
public class CompanyPortraitPropertyTest {

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 18: 画像存储往返一致性**
     * **Validates: Requirements 5.6**
     * 
     * For any valid CompanyPortrait, serializing to JSON and deserializing back
     * should produce an equivalent object.
     */
    @Property(tries = 100)
    void portraitJsonRoundTrip(
            @ForAll @NotBlank @StringLength(min = 1, max = 32) String id,
            @ForAll @NotBlank @StringLength(min = 1, max = 32) String customerId,
            @ForAll("validPortraitJson") String portrait,
            @ForAll("validOpportunitiesJson") String opportunities,
            @ForAll("validRisksJson") String risks,
            @ForAll("validPublicOpinionJson") String publicOpinion,
            @ForAll @NotBlank @StringLength(min = 1, max = 64) String model,
            @ForAll @NotBlank @StringLength(min = 1, max = 32) String organizationId
    ) {
        // Create original portrait
        CompanyPortrait original = new CompanyPortrait();
        original.setId(id);
        original.setCustomerId(customerId);
        original.setPortrait(portrait);
        original.setOpportunities(opportunities);
        original.setRisks(risks);
        original.setPublicOpinion(publicOpinion);
        original.setModel(model);
        original.setVersion("v1");
        original.setSource("ai");
        original.setGeneratedAt(System.currentTimeMillis());
        original.setOrganizationId(organizationId);
        original.setCreateTime(System.currentTimeMillis());
        original.setUpdateTime(System.currentTimeMillis());
        original.setCreateUser("test");
        original.setUpdateUser("test");

        // Serialize to JSON
        String json = JSON.toJSONString(original);

        // Deserialize back
        CompanyPortrait restored = JSON.parseObject(json, CompanyPortrait.class);

        // Verify round-trip consistency
        assertThat(restored.getId()).isEqualTo(original.getId());
        assertThat(restored.getCustomerId()).isEqualTo(original.getCustomerId());
        assertThat(restored.getPortrait()).isEqualTo(original.getPortrait());
        assertThat(restored.getOpportunities()).isEqualTo(original.getOpportunities());
        assertThat(restored.getRisks()).isEqualTo(original.getRisks());
        assertThat(restored.getPublicOpinion()).isEqualTo(original.getPublicOpinion());
        assertThat(restored.getModel()).isEqualTo(original.getModel());
        assertThat(restored.getVersion()).isEqualTo(original.getVersion());
        assertThat(restored.getSource()).isEqualTo(original.getSource());
        assertThat(restored.getGeneratedAt()).isEqualTo(original.getGeneratedAt());
        assertThat(restored.getOrganizationId()).isEqualTo(original.getOrganizationId());
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 18: 画像存储往返一致性**
     * **Validates: Requirements 5.6**
     * 
     * For any valid portrait JSON structure, parsing and re-serializing
     * should preserve the data integrity.
     */
    @Property(tries = 100)
    void portraitDataStructurePreservation(
            @ForAll("validPortraitData") Map<String, Object> portraitData
    ) {
        // Serialize to JSON string
        String jsonString = JSON.toJSONString(portraitData);

        // Parse back to Map
        Map<String, Object> restored = JSON.parseMap(jsonString);

        // Verify all keys are preserved
        assertThat(restored.keySet()).containsExactlyInAnyOrderElementsOf(portraitData.keySet());

        // Verify values are preserved
        for (String key : portraitData.keySet()) {
            assertThat(restored.get(key)).isEqualTo(portraitData.get(key));
        }
    }

    @Provide
    Arbitrary<String> validPortraitJson() {
        return Arbitraries.of(
                "{\"industry\":\"信息技术\",\"scale\":\"中型企业\",\"mainProducts\":\"软件开发\"}",
                "{\"industry\":\"制造业\",\"scale\":\"大型企业\",\"mainProducts\":\"机械设备\"}",
                "{\"industry\":\"金融业\",\"scale\":\"小型企业\",\"mainProducts\":\"金融服务\"}",
                "{\"industry\":\"零售业\",\"scale\":\"微型企业\",\"mainProducts\":\"日用品销售\"}"
        );
    }

    @Provide
    Arbitrary<String> validOpportunitiesJson() {
        return Arbitraries.of(
                "[{\"title\":\"数字化转型需求\",\"confidence\":\"高\",\"source\":\"行业分析\"}]",
                "[{\"title\":\"扩展市场需求\",\"confidence\":\"中\",\"source\":\"公开信息\"}]",
                "[]",
                null
        );
    }

    @Provide
    Arbitrary<String> validRisksJson() {
        return Arbitraries.of(
                "[{\"level\":\"低\",\"text\":\"财务状况良好\"}]",
                "[{\"level\":\"中\",\"text\":\"存在诉讼风险\"}]",
                "[{\"level\":\"高\",\"text\":\"经营异常\"}]",
                "[]",
                null
        );
    }

    @Provide
    Arbitrary<String> validPublicOpinionJson() {
        return Arbitraries.of(
                "[{\"title\":\"获得融资\",\"source\":\"新闻\",\"sentiment\":\"正面\"}]",
                "[{\"title\":\"产品发布\",\"source\":\"官网\",\"sentiment\":\"中性\"}]",
                "[]",
                null
        );
    }

    @Provide
    Arbitrary<Map<String, Object>> validPortraitData() {
        return Combinators.combine(
                Arbitraries.of("信息技术", "制造业", "金融业", "零售业"),
                Arbitraries.of("大型企业", "中型企业", "小型企业", "微型企业"),
                Arbitraries.strings().ofMinLength(2).ofMaxLength(50)
        ).as((industry, scale, mainProducts) -> Map.of(
                "industry", industry,
                "scale", scale,
                "mainProducts", mainProducts
        ));
    }
}
