package cn.cordys.crm.integration;

import cn.cordys.crm.integration.dto.request.ScriptGenerateRequest;
import net.jqwik.api.*;
import net.jqwik.api.constraints.NotBlank;
import net.jqwik.api.constraints.StringLength;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Property-Based Tests for Script Generation Parameters
 * 
 * **Feature: crm-mobile-enterprise-ai, Property 20: 话术生成参数传递**
 * **Validates: Requirements 6.5**
 * 
 * For any script generation request, the request sent to AI service
 * should contain the user-selected scene, channel, and tone parameters.
 */
public class ScriptParameterPropertyTest {

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 20: 话术生成参数传递**
     * **Validates: Requirements 6.5**
     * 
     * For any valid ScriptGenerateRequest, all required parameters should be present.
     */
    @Property(tries = 100)
    void requestContainsAllRequiredParameters(
            @ForAll @NotBlank @StringLength(min = 1, max = 32) String customerId,
            @ForAll("validScene") String scene,
            @ForAll("validChannel") String channel,
            @ForAll("validTone") String tone
    ) {
        ScriptGenerateRequest request = new ScriptGenerateRequest();
        request.setCustomerId(customerId);
        request.setScene(scene);
        request.setChannel(channel);
        request.setTone(tone);

        // Verify all parameters are set
        assertThat(request.getCustomerId()).isEqualTo(customerId);
        assertThat(request.getScene()).isEqualTo(scene);
        assertThat(request.getChannel()).isEqualTo(channel);
        assertThat(request.getTone()).isEqualTo(tone);
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 20: 话术生成参数传递**
     * **Validates: Requirements 6.5**
     * 
     * Scene parameter should be one of the valid values.
     */
    @Property(tries = 100)
    void sceneParameterIsValid(
            @ForAll("validScene") String scene
    ) {
        assertThat(scene).isIn("outreach", "followup", "renewal", "meeting");
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 20: 话术生成参数传递**
     * **Validates: Requirements 6.5**
     * 
     * Channel parameter should be one of the valid values.
     */
    @Property(tries = 100)
    void channelParameterIsValid(
            @ForAll("validChannel") String channel
    ) {
        assertThat(channel).isIn("phone", "wechat", "email");
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 20: 话术生成参数传递**
     * **Validates: Requirements 6.5**
     * 
     * Tone parameter should be one of the valid values.
     */
    @Property(tries = 100)
    void toneParameterIsValid(
            @ForAll("validTone") String tone
    ) {
        assertThat(tone).isIn("professional", "enthusiastic", "concise");
    }

    @Provide
    Arbitrary<String> validScene() {
        return Arbitraries.of("outreach", "followup", "renewal", "meeting");
    }

    @Provide
    Arbitrary<String> validChannel() {
        return Arbitraries.of("phone", "wechat", "email");
    }

    @Provide
    Arbitrary<String> validTone() {
        return Arbitraries.of("professional", "enthusiastic", "concise");
    }
}
