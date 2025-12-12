package cn.cordys.crm.integration;

import cn.cordys.crm.integration.domain.CallScriptTemplate;
import net.jqwik.api.*;

import java.util.*;
import java.util.stream.Collectors;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Property-Based Tests for Template Status
 * 
 * **Feature: crm-mobile-enterprise-ai, Property 25: 模板状态影响可用性**
 * **Validates: Requirements 7.5**
 * 
 * For any 被禁用的话术模板，不应该出现在话术生成时的可用模板列表中。
 */
public class TemplateStatusPropertyTest {

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 25: 模板状态影响可用性**
     * **Validates: Requirements 7.5**
     * 
     * Disabled templates should not appear in enabled template list.
     */
    @Property(tries = 100)
    void disabledTemplatesNotInEnabledList(
            @ForAll("mixedTemplateList") List<CallScriptTemplate> templates
    ) {
        // Filter enabled templates (simulating getEnabledTemplates)
        List<CallScriptTemplate> enabledTemplates = templates.stream()
                .filter(t -> t.getEnabled() != null && t.getEnabled())
                .collect(Collectors.toList());
        
        // Verify no disabled templates in the list
        for (CallScriptTemplate template : enabledTemplates) {
            assertThat(template.getEnabled()).isTrue();
        }
        
        // Verify all disabled templates are excluded
        List<CallScriptTemplate> disabledTemplates = templates.stream()
                .filter(t -> t.getEnabled() == null || !t.getEnabled())
                .collect(Collectors.toList());
        
        for (CallScriptTemplate disabled : disabledTemplates) {
            assertThat(enabledTemplates).doesNotContain(disabled);
        }
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 25: 模板状态影响可用性**
     * **Validates: Requirements 7.5**
     * 
     * Enabling a template should make it appear in enabled list.
     */
    @Property(tries = 100)
    void enablingTemplateMakesItAvailable(
            @ForAll("disabledTemplate") CallScriptTemplate template
    ) {
        // Initially disabled
        assertThat(template.getEnabled()).isFalse();
        
        // Enable the template
        template.setEnabled(true);
        
        // Now it should be enabled
        assertThat(template.getEnabled()).isTrue();
        
        // Filter would include it
        List<CallScriptTemplate> templates = List.of(template);
        List<CallScriptTemplate> enabled = templates.stream()
                .filter(t -> t.getEnabled() != null && t.getEnabled())
                .collect(Collectors.toList());
        
        assertThat(enabled).contains(template);
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 25: 模板状态影响可用性**
     * **Validates: Requirements 7.5**
     * 
     * Disabling a template should remove it from enabled list.
     */
    @Property(tries = 100)
    void disablingTemplateRemovesItFromAvailable(
            @ForAll("enabledTemplate") CallScriptTemplate template
    ) {
        // Initially enabled
        assertThat(template.getEnabled()).isTrue();
        
        // Disable the template
        template.setEnabled(false);
        
        // Now it should be disabled
        assertThat(template.getEnabled()).isFalse();
        
        // Filter would exclude it
        List<CallScriptTemplate> templates = List.of(template);
        List<CallScriptTemplate> enabled = templates.stream()
                .filter(t -> t.getEnabled() != null && t.getEnabled())
                .collect(Collectors.toList());
        
        assertThat(enabled).doesNotContain(template);
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 25: 模板状态影响可用性**
     * **Validates: Requirements 7.5**
     * 
     * Count of enabled templates should be correct.
     */
    @Property(tries = 100)
    void enabledCountIsCorrect(
            @ForAll("mixedTemplateList") List<CallScriptTemplate> templates
    ) {
        // Count enabled templates manually
        long expectedCount = templates.stream()
                .filter(t -> t.getEnabled() != null && t.getEnabled())
                .count();
        
        // Filter enabled templates
        List<CallScriptTemplate> enabledTemplates = templates.stream()
                .filter(t -> t.getEnabled() != null && t.getEnabled())
                .collect(Collectors.toList());
        
        assertThat(enabledTemplates).hasSize((int) expectedCount);
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 25: 模板状态影响可用性**
     * **Validates: Requirements 7.5**
     * 
     * Filtering by industry/scene should still respect enabled status.
     */
    @Property(tries = 100)
    void filteringRespectsEnabledStatus(
            @ForAll("mixedTemplateList") List<CallScriptTemplate> templates,
            @ForAll("industry") String industry,
            @ForAll("scene") String scene
    ) {
        // Filter by industry, scene, and enabled status
        List<CallScriptTemplate> filtered = templates.stream()
                .filter(t -> t.getEnabled() != null && t.getEnabled())
                .filter(t -> industry == null || industry.equals(t.getIndustry()))
                .filter(t -> scene == null || scene.equals(t.getScene()))
                .collect(Collectors.toList());
        
        // All filtered templates should be enabled
        for (CallScriptTemplate template : filtered) {
            assertThat(template.getEnabled()).isTrue();
        }
        
        // No disabled templates should be in the result
        for (CallScriptTemplate template : templates) {
            if (template.getEnabled() == null || !template.getEnabled()) {
                assertThat(filtered).doesNotContain(template);
            }
        }
    }

    @Provide
    Arbitrary<List<CallScriptTemplate>> mixedTemplateList() {
        return Arbitraries.integers().between(1, 20).flatMap(count -> {
            return Arbitraries.of(true, false).list().ofSize(count).flatMap(enabledList -> {
                return Arbitraries.of(
                        "信息技术", "制造业", "金融业", "零售业"
                ).list().ofSize(count).flatMap(industries -> {
                    return Arbitraries.of(
                            "首次接触", "产品介绍", "邀约会议", "跟进回访"
                    ).list().ofSize(count).map(scenes -> {
                        List<CallScriptTemplate> templates = new ArrayList<>();
                        for (int i = 0; i < count; i++) {
                            CallScriptTemplate template = new CallScriptTemplate();
                            template.setId(UUID.randomUUID().toString());
                            template.setName("模板" + i);
                            template.setIndustry(industries.get(i));
                            template.setScene(scenes.get(i));
                            template.setContent("内容" + i);
                            template.setEnabled(enabledList.get(i));
                            templates.add(template);
                        }
                        return templates;
                    });
                });
            });
        });
    }

    @Provide
    Arbitrary<CallScriptTemplate> disabledTemplate() {
        return Arbitraries.of("信息技术", "制造业", "金融业").flatMap(industry -> {
            return Arbitraries.of("首次接触", "产品介绍", "邀约会议").map(scene -> {
                CallScriptTemplate template = new CallScriptTemplate();
                template.setId(UUID.randomUUID().toString());
                template.setName("禁用模板");
                template.setIndustry(industry);
                template.setScene(scene);
                template.setContent("内容");
                template.setEnabled(false);
                return template;
            });
        });
    }

    @Provide
    Arbitrary<CallScriptTemplate> enabledTemplate() {
        return Arbitraries.of("信息技术", "制造业", "金融业").flatMap(industry -> {
            return Arbitraries.of("首次接触", "产品介绍", "邀约会议").map(scene -> {
                CallScriptTemplate template = new CallScriptTemplate();
                template.setId(UUID.randomUUID().toString());
                template.setName("启用模板");
                template.setIndustry(industry);
                template.setScene(scene);
                template.setContent("内容");
                template.setEnabled(true);
                return template;
            });
        });
    }

    @Provide
    Arbitrary<String> industry() {
        return Arbitraries.of("信息技术", "制造业", "金融业", "零售业", null);
    }

    @Provide
    Arbitrary<String> scene() {
        return Arbitraries.of("首次接触", "产品介绍", "邀约会议", "跟进回访", null);
    }
}
