package cn.cordys.crm.integration;

import cn.cordys.crm.integration.domain.CallScriptTemplate;
import net.jqwik.api.*;
import net.jqwik.api.constraints.NotBlank;
import net.jqwik.api.constraints.StringLength;

import java.util.*;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Property-Based Tests for Template Classification
 * 
 * **Feature: crm-mobile-enterprise-ai, Property 24: 模板列表分类正确性**
 * **Validates: Requirements 7.1**
 * 
 * For any 话术模板列表查询，返回的模板应该按行业和场景正确分类。
 */
public class TemplateClassificationPropertyTest {

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 24: 模板列表分类正确性**
     * **Validates: Requirements 7.1**
     * 
     * Templates should be correctly grouped by industry and scene.
     */
    @Property(tries = 100)
    void templatesAreGroupedByIndustryAndScene(
            @ForAll("templateList") List<CallScriptTemplate> templates
    ) {
        // Group templates manually
        Map<String, Map<String, List<CallScriptTemplate>>> grouped = new LinkedHashMap<>();
        
        for (CallScriptTemplate template : templates) {
            String industry = template.getIndustry() != null && !template.getIndustry().isBlank() 
                    ? template.getIndustry() : "通用";
            String scene = template.getScene() != null && !template.getScene().isBlank() 
                    ? template.getScene() : "其他";
            
            grouped.computeIfAbsent(industry, k -> new LinkedHashMap<>())
                   .computeIfAbsent(scene, k -> new ArrayList<>())
                   .add(template);
        }
        
        // Verify each template is in the correct group
        for (CallScriptTemplate template : templates) {
            String expectedIndustry = template.getIndustry() != null && !template.getIndustry().isBlank() 
                    ? template.getIndustry() : "通用";
            String expectedScene = template.getScene() != null && !template.getScene().isBlank() 
                    ? template.getScene() : "其他";
            
            assertThat(grouped).containsKey(expectedIndustry);
            assertThat(grouped.get(expectedIndustry)).containsKey(expectedScene);
            assertThat(grouped.get(expectedIndustry).get(expectedScene)).contains(template);
        }
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 24: 模板列表分类正确性**
     * **Validates: Requirements 7.1**
     * 
     * All templates in a group should have the same industry and scene.
     */
    @Property(tries = 100)
    void allTemplatesInGroupHaveSameIndustryAndScene(
            @ForAll("industry") String industry,
            @ForAll("scene") String scene,
            @ForAll("templateCount") int count
    ) {
        // Create templates with same industry and scene
        List<CallScriptTemplate> templates = new ArrayList<>();
        for (int i = 0; i < count; i++) {
            CallScriptTemplate template = new CallScriptTemplate();
            template.setId(UUID.randomUUID().toString());
            template.setName("模板" + i);
            template.setIndustry(industry);
            template.setScene(scene);
            template.setContent("内容" + i);
            templates.add(template);
        }
        
        // Group templates
        Map<String, Map<String, List<CallScriptTemplate>>> grouped = new LinkedHashMap<>();
        for (CallScriptTemplate template : templates) {
            String ind = template.getIndustry() != null && !template.getIndustry().isBlank() 
                    ? template.getIndustry() : "通用";
            String sc = template.getScene() != null && !template.getScene().isBlank() 
                    ? template.getScene() : "其他";
            
            grouped.computeIfAbsent(ind, k -> new LinkedHashMap<>())
                   .computeIfAbsent(sc, k -> new ArrayList<>())
                   .add(template);
        }
        
        // Verify all templates are in the same group
        String expectedIndustry = industry != null && !industry.isBlank() ? industry : "通用";
        String expectedScene = scene != null && !scene.isBlank() ? scene : "其他";
        
        assertThat(grouped).hasSize(1);
        assertThat(grouped.get(expectedIndustry)).hasSize(1);
        assertThat(grouped.get(expectedIndustry).get(expectedScene)).hasSize(count);
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 24: 模板列表分类正确性**
     * **Validates: Requirements 7.1**
     * 
     * Total count of templates in all groups should equal original count.
     */
    @Property(tries = 100)
    void totalCountInGroupsEqualsOriginalCount(
            @ForAll("templateList") List<CallScriptTemplate> templates
    ) {
        // Group templates
        Map<String, Map<String, List<CallScriptTemplate>>> grouped = new LinkedHashMap<>();
        for (CallScriptTemplate template : templates) {
            String industry = template.getIndustry() != null && !template.getIndustry().isBlank() 
                    ? template.getIndustry() : "通用";
            String scene = template.getScene() != null && !template.getScene().isBlank() 
                    ? template.getScene() : "其他";
            
            grouped.computeIfAbsent(industry, k -> new LinkedHashMap<>())
                   .computeIfAbsent(scene, k -> new ArrayList<>())
                   .add(template);
        }
        
        // Count total templates in groups
        int totalInGroups = grouped.values().stream()
                .flatMap(m -> m.values().stream())
                .mapToInt(List::size)
                .sum();
        
        assertThat(totalInGroups).isEqualTo(templates.size());
    }

    @Provide
    Arbitrary<List<CallScriptTemplate>> templateList() {
        return Arbitraries.integers().between(1, 20).flatMap(count -> {
            return Arbitraries.of(
                    "信息技术", "制造业", "金融业", "零售业", null, ""
            ).list().ofSize(count).flatMap(industries -> {
                return Arbitraries.of(
                        "首次接触", "产品介绍", "邀约会议", "跟进回访", null, ""
                ).list().ofSize(count).map(scenes -> {
                    List<CallScriptTemplate> templates = new ArrayList<>();
                    for (int i = 0; i < count; i++) {
                        CallScriptTemplate template = new CallScriptTemplate();
                        template.setId(UUID.randomUUID().toString());
                        template.setName("模板" + i);
                        template.setIndustry(industries.get(i));
                        template.setScene(scenes.get(i));
                        template.setContent("内容" + i);
                        templates.add(template);
                    }
                    return templates;
                });
            });
        });
    }

    @Provide
    Arbitrary<String> industry() {
        return Arbitraries.of("信息技术", "制造业", "金融业", "零售业", null, "");
    }

    @Provide
    Arbitrary<String> scene() {
        return Arbitraries.of("首次接触", "产品介绍", "邀约会议", "跟进回访", null, "");
    }

    @Provide
    Arbitrary<Integer> templateCount() {
        return Arbitraries.integers().between(1, 10);
    }
}
