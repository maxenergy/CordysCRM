package cn.cordys.crm.integration;

import cn.cordys.crm.integration.service.CallScriptTemplateService;
import net.jqwik.api.*;
import net.jqwik.api.constraints.NotBlank;
import net.jqwik.api.constraints.StringLength;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Property-Based Tests for Template Variable Parsing
 * 
 * **Feature: crm-mobile-enterprise-ai, Property 21: 话术模板变量解析**
 * **Validates: Requirements 7.3**
 * 
 * For any template containing variable placeholders (like {{公司名称}}),
 * the system should correctly identify and list all variables.
 */
public class TemplateVariablePropertyTest {

    private final CallScriptTemplateService templateService = new CallScriptTemplateService();

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 21: 话术模板变量解析**
     * **Validates: Requirements 7.3**
     * 
     * For any template with known variables, parsing should return all variables.
     */
    @Property(tries = 100)
    void parseVariablesFindsAllPlaceholders(
            @ForAll("templateWithVariables") String template,
            @ForAll("expectedVariables") List<String> expectedVars
    ) {
        // Build template with expected variables
        StringBuilder sb = new StringBuilder("您好，");
        for (String var : expectedVars) {
            sb.append("{{").append(var).append("}}，");
        }
        sb.append("感谢您的关注。");
        
        String content = sb.toString();
        List<String> parsed = templateService.parseVariables(content);
        
        // All expected variables should be found
        assertThat(parsed).containsAll(expectedVars);
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 21: 话术模板变量解析**
     * **Validates: Requirements 7.3**
     * 
     * Variable replacement should correctly substitute all placeholders.
     */
    @Property(tries = 100)
    void replaceVariablesSubstitutesAllPlaceholders(
            @ForAll("validVariableName") String varName,
            @ForAll @NotBlank @StringLength(min = 1, max = 50) String varValue
    ) {
        String template = "您好，{{" + varName + "}}，欢迎使用我们的服务。";
        
        Map<String, String> variables = new HashMap<>();
        variables.put(varName, varValue);
        
        String result = templateService.replaceVariables(template, variables);
        
        // Variable should be replaced
        assertThat(result).contains(varValue);
        assertThat(result).doesNotContain("{{" + varName + "}}");
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 21: 话术模板变量解析**
     * **Validates: Requirements 7.3**
     * 
     * Parsing empty or null content should return empty list.
     */
    @Property(tries = 100)
    void parseEmptyContentReturnsEmptyList(
            @ForAll("emptyOrNull") String content
    ) {
        List<String> parsed = templateService.parseVariables(content);
        assertThat(parsed).isEmpty();
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 21: 话术模板变量解析**
     * **Validates: Requirements 7.3**
     * 
     * Duplicate variables should only appear once in the result.
     */
    @Property(tries = 100)
    void duplicateVariablesAreDeduped(
            @ForAll("validVariableName") String varName
    ) {
        String template = "{{" + varName + "}}是{{" + varName + "}}的客户";
        
        List<String> parsed = templateService.parseVariables(template);
        
        // Should only contain the variable once
        assertThat(parsed).hasSize(1);
        assertThat(parsed).contains(varName);
    }

    @Provide
    Arbitrary<String> validVariableName() {
        return Arbitraries.of("公司名称", "联系人", "产品名称", "销售姓名", "客户行业");
    }

    @Provide
    Arbitrary<String> templateWithVariables() {
        return Arbitraries.of(
                "您好，{{公司名称}}，我是{{销售姓名}}",
                "尊敬的{{联系人}}，感谢您对{{产品名称}}的关注",
                "{{公司名称}}的{{联系人}}您好"
        );
    }

    @Provide
    Arbitrary<List<String>> expectedVariables() {
        return Arbitraries.of(
                List.of("公司名称", "联系人"),
                List.of("产品名称"),
                List.of("销售姓名", "公司名称", "联系人")
        );
    }

    @Provide
    Arbitrary<String> emptyOrNull() {
        return Arbitraries.of("", "   ", null);
    }
}
