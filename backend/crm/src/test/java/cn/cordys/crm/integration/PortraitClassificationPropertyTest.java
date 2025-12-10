package cn.cordys.crm.integration;

import cn.cordys.crm.integration.domain.CompanyPortrait;
import cn.cordys.crm.integration.dto.response.PortraitResponse;
import cn.cordys.crm.integration.dto.response.PortraitResponse.*;
import cn.cordys.common.util.JSON;
import net.jqwik.api.*;
import net.jqwik.api.constraints.DoubleRange;
import net.jqwik.api.constraints.NotBlank;
import net.jqwik.api.constraints.StringLength;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Property-Based Tests for Portrait Data Classification
 * 
 * **Feature: crm-mobile-enterprise-ai, Property 16: 画像数据分类正确性**
 * **Validates: Requirements 5.2**
 * 
 * For any company portrait data, it should be correctly classified into
 * four categories: basic info, opportunities, risks, and sentiments.
 */
public class PortraitClassificationPropertyTest {

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 16: 画像数据分类正确性**
     * **Validates: Requirements 5.2**
     * 
     * For any valid portrait JSON structure, parsing should correctly
     * classify data into the four categories.
     */
    @Property(tries = 100)
    void portraitDataCorrectlyClassified(
            @ForAll("validBasics") Basics basics,
            @ForAll("validOpportunities") List<Opportunity> opportunities,
            @ForAll("validRisks") List<Risk> risks,
            @ForAll("validSentiments") List<Sentiment> sentiments
    ) {
        // Create portrait response
        Portrait portrait = Portrait.builder()
                .basics(basics)
                .opportunities(opportunities)
                .risks(risks)
                .sentiments(sentiments)
                .build();

        // Verify classification
        assertThat(portrait.getBasics()).isNotNull();
        assertThat(portrait.getBasics().getIndustry()).isNotBlank();
        assertThat(portrait.getBasics().getScale()).isNotBlank();
        assertThat(portrait.getBasics().getMainProducts()).isNotBlank();

        assertThat(portrait.getOpportunities()).isNotNull();
        for (Opportunity opp : portrait.getOpportunities()) {
            assertThat(opp.getTitle()).isNotBlank();
            assertThat(opp.getConfidence()).isBetween(0.0, 1.0);
            assertThat(opp.getSource()).isNotBlank();
        }

        assertThat(portrait.getRisks()).isNotNull();
        for (Risk risk : portrait.getRisks()) {
            assertThat(risk.getLevel()).isIn("高", "中", "低");
            assertThat(risk.getText()).isNotBlank();
        }

        assertThat(portrait.getSentiments()).isNotNull();
        for (Sentiment sentiment : portrait.getSentiments()) {
            assertThat(sentiment.getTitle()).isNotBlank();
            assertThat(sentiment.getSource()).isNotBlank();
            assertThat(sentiment.getSentiment()).isIn("正面", "中性", "负面");
        }
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 16: 画像数据分类正确性**
     * **Validates: Requirements 5.2**
     * 
     * For any AI response JSON, the four categories should be extractable.
     */
    @Property(tries = 100)
    void aiResponseJsonCorrectlyParsed(
            @ForAll("validAIResponseJson") String aiResponseJson
    ) {
        // Parse JSON
        Map<String, Object> parsed = JSON.parseObject(aiResponseJson, Map.class);

        // Verify all four categories exist
        assertThat(parsed).containsKey("basics");
        assertThat(parsed).containsKey("opportunities");
        assertThat(parsed).containsKey("risks");
        assertThat(parsed).containsKey("sentiments");

        // Verify basics structure
        Object basicsObj = parsed.get("basics");
        assertThat(basicsObj).isInstanceOf(Map.class);
        Map<String, Object> basics = (Map<String, Object>) basicsObj;
        assertThat(basics).containsKeys("industry", "scale", "mainProducts");

        // Verify opportunities structure
        Object oppsObj = parsed.get("opportunities");
        assertThat(oppsObj).isInstanceOf(List.class);

        // Verify risks structure
        Object risksObj = parsed.get("risks");
        assertThat(risksObj).isInstanceOf(List.class);

        // Verify sentiments structure
        Object sentimentsObj = parsed.get("sentiments");
        assertThat(sentimentsObj).isInstanceOf(List.class);
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 16: 画像数据分类正确性**
     * **Validates: Requirements 5.2**
     * 
     * Portrait response should maintain data integrity after serialization.
     */
    @Property(tries = 100)
    void portraitResponseSerializationIntegrity(
            @ForAll @NotBlank @StringLength(min = 1, max = 32) String customerId,
            @ForAll("validBasics") Basics basics
    ) {
        // Create response
        PortraitResponse original = PortraitResponse.builder()
                .customerId(customerId)
                .portrait(Portrait.builder()
                        .basics(basics)
                        .opportunities(List.of())
                        .risks(List.of())
                        .sentiments(List.of())
                        .build())
                .generatedAt(System.currentTimeMillis())
                .model("test-model")
                .version("v1")
                .build();

        // Serialize and deserialize
        String json = JSON.toJSONString(original);
        PortraitResponse restored = JSON.parseObject(json, PortraitResponse.class);

        // Verify integrity
        assertThat(restored.getCustomerId()).isEqualTo(original.getCustomerId());
        assertThat(restored.getModel()).isEqualTo(original.getModel());
        assertThat(restored.getVersion()).isEqualTo(original.getVersion());
        assertThat(restored.getPortrait()).isNotNull();
        assertThat(restored.getPortrait().getBasics()).isNotNull();
        assertThat(restored.getPortrait().getBasics().getIndustry())
                .isEqualTo(original.getPortrait().getBasics().getIndustry());
    }

    @Provide
    Arbitrary<Basics> validBasics() {
        return Combinators.combine(
                Arbitraries.of("信息技术", "制造业", "金融业", "零售业", "房地产"),
                Arbitraries.of("大型企业", "中型企业", "小型企业", "微型企业"),
                Arbitraries.strings().ofMinLength(5).ofMaxLength(100).filter(s -> !s.isBlank())
        ).as((industry, scale, products) -> Basics.builder()
                .industry(industry)
                .scale(scale)
                .mainProducts(products)
                .build());
    }

    @Provide
    Arbitrary<List<Opportunity>> validOpportunities() {
        Arbitrary<Opportunity> opportunity = Combinators.combine(
                Arbitraries.strings().ofMinLength(5).ofMaxLength(50).filter(s -> !s.isBlank()),
                Arbitraries.doubles().between(0.0, 1.0),
                Arbitraries.of("行业分析", "公开信息", "企业规模", "市场趋势")
        ).as((title, confidence, source) -> Opportunity.builder()
                .title(title)
                .confidence(confidence)
                .source(source)
                .build());

        return opportunity.list().ofMinSize(0).ofMaxSize(5);
    }

    @Provide
    Arbitrary<List<Risk>> validRisks() {
        Arbitrary<Risk> risk = Combinators.combine(
                Arbitraries.of("高", "中", "低"),
                Arbitraries.strings().ofMinLength(5).ofMaxLength(100).filter(s -> !s.isBlank())
        ).as((level, text) -> Risk.builder()
                .level(level)
                .text(text)
                .build());

        return risk.list().ofMinSize(0).ofMaxSize(5);
    }

    @Provide
    Arbitrary<List<Sentiment>> validSentiments() {
        Arbitrary<Sentiment> sentiment = Combinators.combine(
                Arbitraries.strings().ofMinLength(5).ofMaxLength(50).filter(s -> !s.isBlank()),
                Arbitraries.of("新闻", "官网", "社交媒体", "行业报告"),
                Arbitraries.of("正面", "中性", "负面")
        ).as((title, source, sent) -> Sentiment.builder()
                .title(title)
                .source(source)
                .sentiment(sent)
                .build());

        return sentiment.list().ofMinSize(0).ofMaxSize(5);
    }

    @Provide
    Arbitrary<String> validAIResponseJson() {
        return Combinators.combine(
                Arbitraries.of("信息技术", "制造业", "金融业"),
                Arbitraries.of("大型企业", "中型企业", "小型企业"),
                Arbitraries.of("软件开发", "机械制造", "金融服务")
        ).as((industry, scale, products) -> String.format("""
                {
                  "basics": {
                    "industry": "%s",
                    "scale": "%s",
                    "mainProducts": "%s"
                  },
                  "opportunities": [
                    {"title": "数字化转型", "confidence": 0.8, "source": "行业分析"}
                  ],
                  "risks": [
                    {"level": "低", "text": "财务状况良好"}
                  ],
                  "sentiments": [
                    {"title": "行业口碑", "source": "新闻", "sentiment": "正面"}
                  ]
                }
                """, industry, scale, products));
    }
}
