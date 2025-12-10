package cn.cordys.crm.integration;

import cn.cordys.crm.integration.domain.EnterpriseProfile;
import cn.cordys.crm.integration.service.EnterpriseService;
import net.jqwik.api.*;
import net.jqwik.api.constraints.AlphaChars;
import net.jqwik.api.constraints.NumericChars;
import net.jqwik.api.constraints.StringLength;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 企业去重属性测试
 * 
 * **Feature: crm-mobile-enterprise-ai, Property 8: 企业去重准确性**
 * **Validates: Requirements 2.5**
 * 
 * @author cordys
 * @date 2025-12-10
 */
class EnterpriseDeduplicationPropertyTest {

    private final EnterpriseService enterpriseService = new EnterpriseService();

    /**
     * Property 8: 企业去重准确性
     * For any 两条企业记录，如果统一社会信用代码相同，则应该被识别为重复记录
     * 
     * **Feature: crm-mobile-enterprise-ai, Property 8: 企业去重准确性**
     * **Validates: Requirements 2.5**
     */
    @Property(tries = 100)
    void sameCreditCodeShouldBeIdentifiedAsDuplicate(
            @ForAll @StringLength(18) @AlphaChars @NumericChars String creditCode,
            @ForAll @StringLength(min = 2, max = 50) String companyName1,
            @ForAll @StringLength(min = 2, max = 50) String companyName2
    ) {
        // Given: 两个企业档案具有相同的统一社会信用代码
        EnterpriseProfile profile1 = createProfile(creditCode, companyName1);
        EnterpriseProfile profile2 = createProfile(creditCode, companyName2);

        // When: 检查是否重复
        boolean isDuplicate = enterpriseService.checkDuplicate(profile1, profile2);

        // Then: 应该被识别为重复记录
        assertThat(isDuplicate)
                .as("两条具有相同统一社会信用代码(%s)的企业记录应该被识别为重复", creditCode)
                .isTrue();
    }

    /**
     * 不同的统一社会信用代码不应该被识别为重复
     * 
     * **Feature: crm-mobile-enterprise-ai, Property 8: 企业去重准确性**
     * **Validates: Requirements 2.5**
     */
    @Property(tries = 100)
    void differentCreditCodeShouldNotBeIdentifiedAsDuplicate(
            @ForAll @StringLength(18) @AlphaChars @NumericChars String creditCode1,
            @ForAll @StringLength(18) @AlphaChars @NumericChars String creditCode2,
            @ForAll @StringLength(min = 2, max = 50) String companyName
    ) {
        // 确保两个信用代码不同
        Assume.that(!creditCode1.equals(creditCode2));

        // Given: 两个企业档案具有不同的统一社会信用代码
        EnterpriseProfile profile1 = createProfile(creditCode1, companyName);
        EnterpriseProfile profile2 = createProfile(creditCode2, companyName);

        // When: 检查是否重复
        boolean isDuplicate = enterpriseService.checkDuplicate(profile1, profile2);

        // Then: 不应该被识别为重复记录
        assertThat(isDuplicate)
                .as("两条具有不同统一社会信用代码的企业记录不应该被识别为重复")
                .isFalse();
    }

    /**
     * 空的统一社会信用代码不应该被识别为重复
     * 
     * **Feature: crm-mobile-enterprise-ai, Property 8: 企业去重准确性**
     * **Validates: Requirements 2.5**
     */
    @Property(tries = 100)
    void emptyCreditCodeShouldNotBeIdentifiedAsDuplicate(
            @ForAll @StringLength(min = 2, max = 50) String companyName1,
            @ForAll @StringLength(min = 2, max = 50) String companyName2
    ) {
        // Given: 两个企业档案都没有统一社会信用代码
        EnterpriseProfile profile1 = createProfile(null, companyName1);
        EnterpriseProfile profile2 = createProfile(null, companyName2);

        // When: 检查是否重复
        boolean isDuplicate = enterpriseService.checkDuplicate(profile1, profile2);

        // Then: 不应该被识别为重复记录
        assertThat(isDuplicate)
                .as("没有统一社会信用代码的企业记录不应该被识别为重复")
                .isFalse();
    }

    /**
     * 空白的统一社会信用代码不应该被识别为重复
     * 
     * **Feature: crm-mobile-enterprise-ai, Property 8: 企业去重准确性**
     * **Validates: Requirements 2.5**
     */
    @Property(tries = 100)
    void blankCreditCodeShouldNotBeIdentifiedAsDuplicate(
            @ForAll @StringLength(min = 2, max = 50) String companyName1,
            @ForAll @StringLength(min = 2, max = 50) String companyName2
    ) {
        // Given: 两个企业档案的统一社会信用代码为空白字符串
        EnterpriseProfile profile1 = createProfile("", companyName1);
        EnterpriseProfile profile2 = createProfile("   ", companyName2);

        // When: 检查是否重复
        boolean isDuplicate = enterpriseService.checkDuplicate(profile1, profile2);

        // Then: 不应该被识别为重复记录
        assertThat(isDuplicate)
                .as("空白统一社会信用代码的企业记录不应该被识别为重复")
                .isFalse();
    }

    /**
     * null企业档案不应该被识别为重复
     */
    @Example
    void nullProfileShouldNotBeIdentifiedAsDuplicate() {
        EnterpriseProfile profile = createProfile("123456789012345678", "测试公司");

        assertThat(enterpriseService.checkDuplicate((EnterpriseProfile) null, profile)).isFalse();
        assertThat(enterpriseService.checkDuplicate(profile, (EnterpriseProfile) null)).isFalse();
        assertThat(enterpriseService.checkDuplicate((EnterpriseProfile) null, (EnterpriseProfile) null)).isFalse();
    }

    /**
     * 创建测试用企业档案
     */
    private EnterpriseProfile createProfile(String creditCode, String companyName) {
        EnterpriseProfile profile = new EnterpriseProfile();
        profile.setCreditCode(creditCode);
        profile.setCompanyName(companyName);
        return profile;
    }
}
