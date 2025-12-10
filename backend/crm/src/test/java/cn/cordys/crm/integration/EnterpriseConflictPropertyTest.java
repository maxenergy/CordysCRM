package cn.cordys.crm.integration;

import cn.cordys.crm.integration.domain.EnterpriseProfile;
import cn.cordys.crm.integration.dto.request.EnterpriseImportRequest;
import cn.cordys.crm.integration.dto.response.EnterpriseImportResponse.FieldConflict;
import cn.cordys.crm.integration.service.EnterpriseService;
import net.jqwik.api.*;
import net.jqwik.api.constraints.AlphaChars;
import net.jqwik.api.constraints.NumericChars;
import net.jqwik.api.constraints.StringLength;

import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 企业冲突检测属性测试
 * 
 * **Feature: crm-mobile-enterprise-ai, Property 9: 冲突检测准确性**
 * **Validates: Requirements 2.6**
 * 
 * @author cordys
 * @date 2025-12-10
 */
class EnterpriseConflictPropertyTest {

    private final EnterpriseService enterpriseService = new EnterpriseService();

    /**
     * Property 9: 冲突检测准确性
     * For any 两条企业记录的相同字段，如果值不同，则该字段应该出现在冲突列表中
     * 
     * **Feature: crm-mobile-enterprise-ai, Property 9: 冲突检测准确性**
     * **Validates: Requirements 2.6**
     */
    @Property(tries = 100)
    void differentFieldValuesShouldBeDetectedAsConflict(
            @ForAll @StringLength(18) @AlphaChars @NumericChars String creditCode,
            @ForAll("nonBlankStrings") String phone1,
            @ForAll("nonBlankStrings") String phone2
    ) {
        // 确保两个电话号码不同
        Assume.that(!phone1.equals(phone2));

        // Given: 现有记录和导入请求的电话号码不同
        EnterpriseProfile existing = createProfile(creditCode, "测试公司");
        existing.setPhone(phone1);
        
        EnterpriseImportRequest request = createRequest(creditCode, "测试公司");
        request.setPhone(phone2);

        // When: 检测冲突
        List<FieldConflict> conflicts = enterpriseService.detectConflicts(existing, request);

        // Then: 电话字段应该出现在冲突列表中
        Set<String> conflictFields = conflicts.stream()
                .map(FieldConflict::getField)
                .collect(Collectors.toSet());
        
        assertThat(conflictFields)
                .as("不同的电话号码应该被检测为冲突")
                .contains("phone");
    }

    @Provide
    Arbitrary<String> nonBlankStrings() {
        return Arbitraries.strings()
                .alpha()
                .numeric()
                .ofMinLength(3)
                .ofMaxLength(20)
                .filter(s -> s != null && !s.trim().isEmpty());
    }

    /**
     * 相同字段值不应该被检测为冲突
     * 
     * **Feature: crm-mobile-enterprise-ai, Property 9: 冲突检测准确性**
     * **Validates: Requirements 2.6**
     */
    @Property(tries = 100)
    void sameFieldValuesShouldNotBeDetectedAsConflict(
            @ForAll @StringLength(18) @AlphaChars @NumericChars String creditCode,
            @ForAll @StringLength(min = 2, max = 50) String companyName,
            @ForAll @StringLength(min = 2, max = 20) String legalPerson,
            @ForAll @StringLength(min = 5, max = 100) String address
    ) {
        // Given: 现有记录和导入请求的所有字段值相同
        EnterpriseProfile existing = createProfile(creditCode, companyName);
        existing.setLegalPerson(legalPerson);
        existing.setAddress(address);
        
        EnterpriseImportRequest request = createRequest(creditCode, companyName);
        request.setLegalPerson(legalPerson);
        request.setAddress(address);

        // When: 检测冲突
        List<FieldConflict> conflicts = enterpriseService.detectConflicts(existing, request);

        // Then: 不应该有冲突
        assertThat(conflicts)
                .as("相同的字段值不应该被检测为冲突")
                .isEmpty();
    }

    /**
     * 多个不同字段应该都被检测为冲突
     * 
     * **Feature: crm-mobile-enterprise-ai, Property 9: 冲突检测准确性**
     * **Validates: Requirements 2.6**
     */
    @Property(tries = 100)
    void multipleConflictsShouldAllBeDetected(
            @ForAll @StringLength(18) @AlphaChars @NumericChars String creditCode,
            @ForAll("nonBlankStrings") String phone1,
            @ForAll("nonBlankStrings") String phone2,
            @ForAll("nonBlankStrings") String email1,
            @ForAll("nonBlankStrings") String email2
    ) {
        // 确保所有字段都不同
        Assume.that(!phone1.equals(phone2));
        Assume.that(!email1.equals(email2));

        // Given: 现有记录和导入请求的多个字段值不同
        EnterpriseProfile existing = createProfile(creditCode, "测试公司");
        existing.setPhone(phone1);
        existing.setEmail(email1);
        
        EnterpriseImportRequest request = createRequest(creditCode, "测试公司");
        request.setPhone(phone2);
        request.setEmail(email2);

        // When: 检测冲突
        List<FieldConflict> conflicts = enterpriseService.detectConflicts(existing, request);

        // Then: 所有不同的字段都应该出现在冲突列表中
        Set<String> conflictFields = conflicts.stream()
                .map(FieldConflict::getField)
                .collect(Collectors.toSet());
        
        assertThat(conflictFields)
                .as("所有不同的字段都应该被检测为冲突")
                .containsExactlyInAnyOrder("phone", "email");
    }

    /**
     * 空的远程值不应该被检测为冲突
     * 
     * **Feature: crm-mobile-enterprise-ai, Property 9: 冲突检测准确性**
     * **Validates: Requirements 2.6**
     */
    @Property(tries = 100)
    void emptyRemoteValueShouldNotBeDetectedAsConflict(
            @ForAll @StringLength(18) @AlphaChars @NumericChars String creditCode,
            @ForAll @StringLength(min = 2, max = 50) String companyName,
            @ForAll @StringLength(min = 2, max = 20) String legalPerson
    ) {
        // Given: 现有记录有法人信息，但导入请求没有
        EnterpriseProfile existing = createProfile(creditCode, companyName);
        existing.setLegalPerson(legalPerson);
        
        EnterpriseImportRequest request = createRequest(creditCode, companyName);
        request.setLegalPerson(null); // 远程值为空

        // When: 检测冲突
        List<FieldConflict> conflicts = enterpriseService.detectConflicts(existing, request);

        // Then: 法人字段不应该出现在冲突列表中
        Set<String> conflictFields = conflicts.stream()
                .map(FieldConflict::getField)
                .collect(Collectors.toSet());
        
        assertThat(conflictFields)
                .as("空的远程值不应该被检测为冲突")
                .doesNotContain("legalPerson");
    }

    /**
     * 空的本地值不应该被检测为冲突（直接更新）
     * 
     * **Feature: crm-mobile-enterprise-ai, Property 9: 冲突检测准确性**
     * **Validates: Requirements 2.6**
     */
    @Property(tries = 100)
    void emptyLocalValueShouldNotBeDetectedAsConflict(
            @ForAll @StringLength(18) @AlphaChars @NumericChars String creditCode,
            @ForAll @StringLength(min = 2, max = 50) String companyName,
            @ForAll @StringLength(min = 2, max = 20) String legalPerson
    ) {
        // Given: 现有记录没有法人信息，但导入请求有
        EnterpriseProfile existing = createProfile(creditCode, companyName);
        existing.setLegalPerson(null); // 本地值为空
        
        EnterpriseImportRequest request = createRequest(creditCode, companyName);
        request.setLegalPerson(legalPerson);

        // When: 检测冲突
        List<FieldConflict> conflicts = enterpriseService.detectConflicts(existing, request);

        // Then: 法人字段不应该出现在冲突列表中
        Set<String> conflictFields = conflicts.stream()
                .map(FieldConflict::getField)
                .collect(Collectors.toSet());
        
        assertThat(conflictFields)
                .as("空的本地值不应该被检测为冲突")
                .doesNotContain("legalPerson");
    }

    /**
     * 冲突记录应该包含正确的本地值和远程值
     * 
     * **Feature: crm-mobile-enterprise-ai, Property 9: 冲突检测准确性**
     * **Validates: Requirements 2.6**
     */
    @Property(tries = 100)
    void conflictShouldContainCorrectValues(
            @ForAll @StringLength(18) @AlphaChars @NumericChars String creditCode,
            @ForAll("nonBlankStrings") String phone1,
            @ForAll("nonBlankStrings") String phone2
    ) {
        // 确保两个电话号码不同
        Assume.that(!phone1.equals(phone2));

        // Given: 现有记录和导入请求的电话号码不同
        EnterpriseProfile existing = createProfile(creditCode, "测试公司");
        existing.setPhone(phone1);
        
        EnterpriseImportRequest request = createRequest(creditCode, "测试公司");
        request.setPhone(phone2);

        // When: 检测冲突
        List<FieldConflict> conflicts = enterpriseService.detectConflicts(existing, request);

        // Then: 冲突记录应该包含正确的本地值和远程值
        FieldConflict phoneConflict = conflicts.stream()
                .filter(c -> "phone".equals(c.getField()))
                .findFirst()
                .orElse(null);
        
        assertThat(phoneConflict).isNotNull();
        assertThat(phoneConflict.getLocalValue())
                .as("冲突记录的本地值应该是现有记录的值")
                .isEqualTo(phone1);
        assertThat(phoneConflict.getRemoteValue())
                .as("冲突记录的远程值应该是导入请求的值")
                .isEqualTo(phone2);
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

    /**
     * 创建测试用导入请求
     */
    private EnterpriseImportRequest createRequest(String creditCode, String companyName) {
        EnterpriseImportRequest request = new EnterpriseImportRequest();
        request.setCreditCode(creditCode);
        request.setCompanyName(companyName);
        return request;
    }
}
