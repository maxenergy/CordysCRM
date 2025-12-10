package cn.cordys.crm.integration;

import cn.cordys.crm.integration.domain.CallScript;
import cn.cordys.common.util.JSON;
import net.jqwik.api.*;
import net.jqwik.api.constraints.NotBlank;
import net.jqwik.api.constraints.StringLength;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Property-Based Tests for CallScript entity
 * 
 * **Feature: crm-mobile-enterprise-ai, Property 22: 话术保存往返一致性**
 * **Validates: Requirements 6.8**
 * 
 * For any user-edited call script, saving and then querying
 * should return exactly the same content.
 */
public class CallScriptPropertyTest {

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 22: 话术保存往返一致性**
     * **Validates: Requirements 6.8**
     * 
     * For any valid CallScript, serializing to JSON and deserializing back
     * should produce an equivalent object with identical content.
     */
    @Property(tries = 100)
    void callScriptJsonRoundTrip(
            @ForAll @NotBlank @StringLength(min = 1, max = 32) String id,
            @ForAll @NotBlank @StringLength(min = 1, max = 32) String customerId,
            @ForAll("validScene") String scene,
            @ForAll("validChannel") String channel,
            @ForAll("validTone") String tone,
            @ForAll("validContent") String content,
            @ForAll @NotBlank @StringLength(min = 1, max = 32) String organizationId
    ) {
        // Create original call script
        CallScript original = new CallScript();
        original.setId(id);
        original.setCustomerId(customerId);
        original.setScene(scene);
        original.setChannel(channel);
        original.setLanguage("zh-CN");
        original.setTone(tone);
        original.setContent(content);
        original.setModel("gpt-4");
        original.setGeneratedAt(System.currentTimeMillis());
        original.setOrganizationId(organizationId);
        original.setCreateTime(System.currentTimeMillis());
        original.setUpdateTime(System.currentTimeMillis());
        original.setCreateUser("test");
        original.setUpdateUser("test");

        // Serialize to JSON
        String json = JSON.toJSONString(original);

        // Deserialize back
        CallScript restored = JSON.parseObject(json, CallScript.class);

        // Verify round-trip consistency - especially content field
        assertThat(restored.getId()).isEqualTo(original.getId());
        assertThat(restored.getCustomerId()).isEqualTo(original.getCustomerId());
        assertThat(restored.getScene()).isEqualTo(original.getScene());
        assertThat(restored.getChannel()).isEqualTo(original.getChannel());
        assertThat(restored.getLanguage()).isEqualTo(original.getLanguage());
        assertThat(restored.getTone()).isEqualTo(original.getTone());
        assertThat(restored.getContent()).isEqualTo(original.getContent());
        assertThat(restored.getModel()).isEqualTo(original.getModel());
        assertThat(restored.getGeneratedAt()).isEqualTo(original.getGeneratedAt());
        assertThat(restored.getOrganizationId()).isEqualTo(original.getOrganizationId());
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 22: 话术保存往返一致性**
     * **Validates: Requirements 6.8**
     * 
     * For any call script content with special characters (newlines, quotes, unicode),
     * serializing and deserializing should preserve the exact content.
     */
    @Property(tries = 100)
    void callScriptContentWithSpecialCharsPreserved(
            @ForAll("contentWithSpecialChars") String content
    ) {
        CallScript original = new CallScript();
        original.setId("test-id");
        original.setCustomerId("customer-1");
        original.setScene("outreach");
        original.setChannel("phone");
        original.setContent(content);
        original.setOrganizationId("org-1");

        // Serialize to JSON
        String json = JSON.toJSONString(original);

        // Deserialize back
        CallScript restored = JSON.parseObject(json, CallScript.class);

        // Content must be exactly preserved
        assertThat(restored.getContent()).isEqualTo(original.getContent());
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 22: 话术保存往返一致性**
     * **Validates: Requirements 6.8**
     * 
     * For any call script with tags JSON, the tags should be preserved after round-trip.
     */
    @Property(tries = 100)
    void callScriptTagsPreserved(
            @ForAll("validTags") String tags
    ) {
        CallScript original = new CallScript();
        original.setId("test-id");
        original.setCustomerId("customer-1");
        original.setScene("outreach");
        original.setChannel("phone");
        original.setContent("测试话术内容");
        original.setTags(tags);
        original.setOrganizationId("org-1");

        // Serialize to JSON
        String json = JSON.toJSONString(original);

        // Deserialize back
        CallScript restored = JSON.parseObject(json, CallScript.class);

        // Tags must be exactly preserved
        assertThat(restored.getTags()).isEqualTo(original.getTags());
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

    @Provide
    Arbitrary<String> validContent() {
        return Arbitraries.of(
                "您好，我是XX公司的销售代表，请问您现在方便吗？",
                "感谢您上次的沟通，我想跟进一下您对我们产品的看法。",
                "尊敬的客户，我们有一个新的优惠活动想向您介绍。",
                "您好！很高兴能与您联系，我们公司专注于为企业提供数字化解决方案。"
        );
    }

    @Provide
    Arbitrary<String> contentWithSpecialChars() {
        return Arbitraries.of(
                "第一行\n第二行\n第三行",
                "包含\"引号\"的内容",
                "包含'单引号'的内容",
                "包含特殊字符：@#$%^&*()",
                "包含中文标点：，。！？、；：",
                "混合内容：Hello 你好 123 ！@#",
                "包含制表符\t和换行\n的内容",
                "Unicode字符：😀🎉✅"
        );
    }

    @Provide
    Arbitrary<String> validTags() {
        return Arbitraries.of(
                "[\"首次接触\",\"产品介绍\"]",
                "[\"跟进回访\"]",
                "[\"邀约会议\",\"重要客户\",\"VIP\"]",
                "[]",
                null
        );
    }
}
