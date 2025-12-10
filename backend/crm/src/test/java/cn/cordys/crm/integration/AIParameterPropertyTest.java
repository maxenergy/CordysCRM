package cn.cordys.crm.integration;

import cn.cordys.crm.integration.domain.EnterpriseProfile;
import cn.cordys.crm.integration.service.PortraitService;
import net.jqwik.api.*;
import net.jqwik.api.constraints.NotBlank;
import net.jqwik.api.constraints.StringLength;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Property-Based Tests for AI Parameter Completeness
 * 
 * **Feature: crm-mobile-enterprise-ai, Property 17: AI调用参数完整性**
 * **Validates: Requirements 5.5**
 * 
 * For any portrait generation request, the Prompt sent to AI service
 * should contain the enterprise's basic information (name, industry, scale, etc.)
 */
public class AIParameterPropertyTest {

    private final PortraitService portraitService = new PortraitService();

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 17: AI调用参数完整性**
     * **Validates: Requirements 5.5**
     * 
     * For any valid EnterpriseProfile, the generated prompt should contain
     * all required basic information fields.
     */
    @Property(tries = 100)
    void promptContainsAllBasicInfo(
            @ForAll @NotBlank @StringLength(min = 2, max = 100) String companyName,
            @ForAll @StringLength(min = 18, max = 18) String creditCode,
            @ForAll @NotBlank @StringLength(min = 2, max = 20) String legalPerson,
            @ForAll("validIndustry") String industryName,
            @ForAll("validStaffSize") String staffSize,
            @ForAll @StringLength(min = 5, max = 200) String address
    ) {
        // Create enterprise profile with test data
        EnterpriseProfile profile = new EnterpriseProfile();
        profile.setCompanyName(companyName);
        profile.setCreditCode(creditCode);
        profile.setLegalPerson(legalPerson);
        profile.setIndustryName(industryName);
        profile.setStaffSize(staffSize);
        profile.setAddress(address);
        profile.setRegCapital(new BigDecimal("1000"));

        // Build prompt
        String prompt = portraitService.buildPrompt(profile);

        // Verify prompt contains all required fields
        assertThat(prompt).isNotBlank();
        assertThat(prompt).contains("企业名称");
        assertThat(prompt).contains(companyName);
        assertThat(prompt).contains("统一社会信用代码");
        assertThat(prompt).contains(creditCode);
        assertThat(prompt).contains("法定代表人");
        assertThat(prompt).contains(legalPerson);
        assertThat(prompt).contains("所属行业");
        assertThat(prompt).contains(industryName);
        assertThat(prompt).contains("员工规模");
        assertThat(prompt).contains(staffSize);
        assertThat(prompt).contains("注册地址");
        assertThat(prompt).contains(address);
        assertThat(prompt).contains("注册资本");
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 17: AI调用参数完整性**
     * **Validates: Requirements 5.5**
     * 
     * For any EnterpriseProfile with null fields, the prompt should still be valid
     * and contain placeholder values for missing fields.
     */
    @Property(tries = 100)
    void promptHandlesNullFields(
            @ForAll @NotBlank @StringLength(min = 2, max = 100) String companyName
    ) {
        // Create enterprise profile with minimal data
        EnterpriseProfile profile = new EnterpriseProfile();
        profile.setCompanyName(companyName);
        // Other fields are null

        // Build prompt
        String prompt = portraitService.buildPrompt(profile);

        // Verify prompt is still valid and contains company name
        assertThat(prompt).isNotBlank();
        assertThat(prompt).contains(companyName);
        // Null fields should show "未知"
        assertThat(prompt).contains("未知");
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 17: AI调用参数完整性**
     * **Validates: Requirements 5.5**
     * 
     * The prompt should have a consistent structure regardless of input data.
     */
    @Property(tries = 100)
    void promptHasConsistentStructure(
            @ForAll("enterpriseProfiles") EnterpriseProfile profile
    ) {
        String prompt = portraitService.buildPrompt(profile);

        // Verify prompt structure
        assertThat(prompt).contains("【企业基本信息】");
        assertThat(prompt).contains("企业名称:");
        assertThat(prompt).contains("统一社会信用代码:");
        assertThat(prompt).contains("法定代表人:");
        assertThat(prompt).contains("注册资本:");
        assertThat(prompt).contains("所属行业:");
        assertThat(prompt).contains("员工规模:");
        assertThat(prompt).contains("注册地址:");
    }

    @Provide
    Arbitrary<String> validIndustry() {
        return Arbitraries.of(
                "信息技术",
                "制造业",
                "金融业",
                "零售业",
                "房地产",
                "教育",
                "医疗健康",
                "交通运输"
        );
    }

    @Provide
    Arbitrary<String> validStaffSize() {
        return Arbitraries.of(
                "1-10人",
                "11-50人",
                "51-100人",
                "101-500人",
                "501-1000人",
                "1000人以上"
        );
    }

    @Provide
    Arbitrary<EnterpriseProfile> enterpriseProfiles() {
        return Combinators.combine(
                Arbitraries.strings().ofMinLength(2).ofMaxLength(100).filter(s -> !s.isBlank()),
                Arbitraries.strings().ofLength(18).alpha().numeric(),
                Arbitraries.strings().ofMinLength(2).ofMaxLength(20),
                validIndustry(),
                validStaffSize(),
                Arbitraries.strings().ofMinLength(5).ofMaxLength(200)
        ).as((name, code, legal, industry, staff, addr) -> {
            EnterpriseProfile profile = new EnterpriseProfile();
            profile.setCompanyName(name);
            profile.setCreditCode(code);
            profile.setLegalPerson(legal);
            profile.setIndustryName(industry);
            profile.setStaffSize(staff);
            profile.setAddress(addr);
            profile.setRegCapital(new BigDecimal("1000"));
            return profile;
        });
    }
}
