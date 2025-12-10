package cn.cordys.crm.integration.service;

import cn.cordys.common.uid.IDGenerator;
import cn.cordys.security.SessionUtils;
import cn.cordys.crm.integration.domain.EnterpriseProfile;
import cn.cordys.crm.integration.dto.request.EnterpriseImportRequest;
import cn.cordys.crm.integration.dto.response.EnterpriseImportResponse;
import cn.cordys.crm.integration.dto.response.EnterpriseImportResponse.FieldConflict;
import cn.cordys.crm.integration.mapper.ExtEnterpriseProfileMapper;
import cn.cordys.mybatis.BaseMapper;
import jakarta.annotation.Resource;
import org.apache.commons.lang3.StringUtils;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

/**
 * 企业信息服务
 * 实现企业信息导入、去重检查、冲突检测等核心业务逻辑
 * 
 * Requirements: 2.5, 2.6, 3.6
 * 
 * @author cordys
 * @date 2025-12-10
 */
@Service
public class EnterpriseService {

    @Resource
    private BaseMapper<EnterpriseProfile> enterpriseProfileMapper;

    @Resource
    private ExtEnterpriseProfileMapper extEnterpriseProfileMapper;

    /**
     * 导入企业信息
     * 
     * @param request 导入请求
     * @param organizationId 组织ID
     * @return 导入结果
     */
    @Transactional(rollbackFor = Exception.class)
    public EnterpriseImportResponse importEnterprise(EnterpriseImportRequest request, String organizationId) {
        // 1. 检查是否存在重复记录（基于统一社会信用代码）
        EnterpriseProfile existing = findByCreditCode(request.getCreditCode(), organizationId);
        
        if (existing != null) {
            // 2. 检测冲突字段
            List<FieldConflict> conflicts = detectConflicts(existing, request);
            
            if (!conflicts.isEmpty()) {
                // 存在冲突，返回冲突列表供用户选择
                return EnterpriseImportResponse.conflict(existing.getCustomerId(), conflicts);
            }
            
            // 无冲突，更新现有记录
            updateEnterpriseProfile(existing, request);
            return EnterpriseImportResponse.successUpdate(existing.getCustomerId(), existing.getId());
        }
        
        // 3. 创建新记录
        EnterpriseProfile newProfile = createEnterpriseProfile(request, organizationId);
        return EnterpriseImportResponse.successNew(newProfile.getCustomerId(), newProfile.getId());
    }

    /**
     * 强制导入企业信息（覆盖冲突）
     * 
     * @param request 导入请求
     * @param organizationId 组织ID
     * @return 导入结果
     */
    @Transactional(rollbackFor = Exception.class)
    public EnterpriseImportResponse forceImportEnterprise(EnterpriseImportRequest request, String organizationId) {
        EnterpriseProfile existing = findByCreditCode(request.getCreditCode(), organizationId);
        
        if (existing != null) {
            updateEnterpriseProfile(existing, request);
            return EnterpriseImportResponse.successUpdate(existing.getCustomerId(), existing.getId());
        }
        
        EnterpriseProfile newProfile = createEnterpriseProfile(request, organizationId);
        return EnterpriseImportResponse.successNew(newProfile.getCustomerId(), newProfile.getId());
    }

    /**
     * 检查是否存在重复记录（基于统一社会信用代码）
     * 
     * Property 8: 企业去重准确性
     * For any 两条企业记录，如果统一社会信用代码相同，则应该被识别为重复记录
     * 
     * @param creditCode 统一社会信用代码
     * @param organizationId 组织ID
     * @return 是否重复
     */
    public boolean checkDuplicate(String creditCode, String organizationId) {
        if (StringUtils.isBlank(creditCode)) {
            return false;
        }
        return findByCreditCode(creditCode, organizationId) != null;
    }

    /**
     * 检查两个企业档案是否重复（基于统一社会信用代码）
     * 
     * Property 8: 企业去重准确性
     * 
     * @param profile1 企业档案1
     * @param profile2 企业档案2
     * @return 是否重复
     */
    public boolean checkDuplicate(EnterpriseProfile profile1, EnterpriseProfile profile2) {
        if (profile1 == null || profile2 == null) {
            return false;
        }
        String code1 = profile1.getCreditCode();
        String code2 = profile2.getCreditCode();
        if (StringUtils.isBlank(code1) || StringUtils.isBlank(code2)) {
            return false;
        }
        return code1.equals(code2);
    }

    /**
     * 检测冲突字段
     * 
     * Property 9: 冲突检测准确性
     * For any 两条企业记录的相同字段，如果值不同，则该字段应该出现在冲突列表中
     * 
     * @param existing 现有记录
     * @param request 导入请求
     * @return 冲突字段列表
     */
    public List<FieldConflict> detectConflicts(EnterpriseProfile existing, EnterpriseImportRequest request) {
        List<FieldConflict> conflicts = new ArrayList<>();
        
        // 检测各字段冲突
        addConflictIfDifferent(conflicts, "companyName", "企业名称", 
                existing.getCompanyName(), request.getCompanyName());
        addConflictIfDifferent(conflicts, "legalPerson", "法定代表人", 
                existing.getLegalPerson(), request.getLegalPerson());
        addConflictIfDifferent(conflicts, "address", "注册地址", 
                existing.getAddress(), request.getAddress());
        addConflictIfDifferent(conflicts, "phone", "联系电话", 
                existing.getPhone(), request.getPhone());
        addConflictIfDifferent(conflicts, "email", "邮箱", 
                existing.getEmail(), request.getEmail());
        addConflictIfDifferent(conflicts, "website", "官网", 
                existing.getWebsite(), request.getWebsite());
        addConflictIfDifferent(conflicts, "staffSize", "人员规模", 
                existing.getStaffSize(), request.getStaffSize());
        addConflictIfDifferent(conflicts, "industryName", "行业名称", 
                existing.getIndustryName(), request.getIndustry());
        addConflictIfDifferent(conflicts, "status", "经营状态", 
                existing.getStatus(), request.getStatus());
        
        // 注册资本比较
        if (existing.getRegCapital() != null && request.getRegisteredCapital() != null) {
            if (existing.getRegCapital().compareTo(request.getRegisteredCapital()) != 0) {
                conflicts.add(FieldConflict.builder()
                        .field("registeredCapital")
                        .fieldLabel("注册资本")
                        .localValue(existing.getRegCapital().toString())
                        .remoteValue(request.getRegisteredCapital().toString())
                        .build());
            }
        }
        
        return conflicts;
    }

    /**
     * 根据统一社会信用代码查找企业档案
     * 
     * @param creditCode 统一社会信用代码
     * @param organizationId 组织ID
     * @return 企业档案
     */
    public EnterpriseProfile findByCreditCode(String creditCode, String organizationId) {
        if (StringUtils.isBlank(creditCode)) {
            return null;
        }
        return extEnterpriseProfileMapper.selectByCreditCode(creditCode, organizationId);
    }

    /**
     * 根据客户ID查找企业档案
     * 
     * @param customerId 客户ID
     * @return 企业档案
     */
    public EnterpriseProfile findByCustomerId(String customerId) {
        if (StringUtils.isBlank(customerId)) {
            return null;
        }
        return extEnterpriseProfileMapper.selectByCustomerId(customerId);
    }

    /**
     * 创建新的企业档案
     */
    private EnterpriseProfile createEnterpriseProfile(EnterpriseImportRequest request, String organizationId) {
        EnterpriseProfile profile = new EnterpriseProfile();
        profile.setId(IDGenerator.nextStr());
        
        // 如果提供了客户ID则使用，否则生成新的
        if (StringUtils.isNotBlank(request.getCustomerId())) {
            profile.setCustomerId(request.getCustomerId());
        } else {
            profile.setCustomerId(IDGenerator.nextStr());
        }
        
        copyRequestToProfile(request, profile);
        profile.setOrganizationId(organizationId);
        profile.setCreateTime(System.currentTimeMillis());
        profile.setUpdateTime(System.currentTimeMillis());
        profile.setCreateUser(SessionUtils.getUserId());
        profile.setUpdateUser(SessionUtils.getUserId());
        profile.setLastSyncAt(System.currentTimeMillis());
        
        enterpriseProfileMapper.insert(profile);
        return profile;
    }

    /**
     * 更新企业档案
     */
    private void updateEnterpriseProfile(EnterpriseProfile existing, EnterpriseImportRequest request) {
        copyRequestToProfile(request, existing);
        existing.setUpdateTime(System.currentTimeMillis());
        existing.setUpdateUser(SessionUtils.getUserId());
        existing.setLastSyncAt(System.currentTimeMillis());
        
        enterpriseProfileMapper.update(existing);
    }

    /**
     * 复制请求数据到企业档案
     */
    private void copyRequestToProfile(EnterpriseImportRequest request, EnterpriseProfile profile) {
        profile.setCreditCode(request.getCreditCode());
        profile.setCompanyName(request.getCompanyName());
        profile.setIqichaId(request.getIqichaId());
        
        if (StringUtils.isNotBlank(request.getLegalPerson())) {
            profile.setLegalPerson(request.getLegalPerson());
        }
        if (request.getRegisteredCapital() != null) {
            profile.setRegCapital(request.getRegisteredCapital());
        }
        if (request.getEstablishmentDate() != null) {
            profile.setRegDate(request.getEstablishmentDate());
        }
        if (StringUtils.isNotBlank(request.getAddress())) {
            profile.setAddress(request.getAddress());
        }
        if (StringUtils.isNotBlank(request.getProvince())) {
            profile.setProvince(request.getProvince());
        }
        if (StringUtils.isNotBlank(request.getCity())) {
            profile.setCity(request.getCity());
        }
        if (StringUtils.isNotBlank(request.getIndustry())) {
            profile.setIndustryName(request.getIndustry());
        }
        if (StringUtils.isNotBlank(request.getIndustryCode())) {
            profile.setIndustryCode(request.getIndustryCode());
        }
        if (StringUtils.isNotBlank(request.getStaffSize())) {
            profile.setStaffSize(request.getStaffSize());
        }
        if (StringUtils.isNotBlank(request.getPhone())) {
            profile.setPhone(request.getPhone());
        }
        if (StringUtils.isNotBlank(request.getEmail())) {
            profile.setEmail(request.getEmail());
        }
        if (StringUtils.isNotBlank(request.getWebsite())) {
            profile.setWebsite(request.getWebsite());
        }
        if (StringUtils.isNotBlank(request.getStatus())) {
            profile.setStatus(request.getStatus());
        }
        if (StringUtils.isNotBlank(request.getSource())) {
            profile.setSource(request.getSource());
        } else {
            profile.setSource("manual");
        }
        if (StringUtils.isNotBlank(request.getShareholders())) {
            profile.setShareholders(request.getShareholders());
        }
        if (StringUtils.isNotBlank(request.getExecutives())) {
            profile.setExecutives(request.getExecutives());
        }
        if (StringUtils.isNotBlank(request.getRisks())) {
            profile.setRisks(request.getRisks());
        }
    }

    /**
     * 如果两个值不同，添加冲突记录
     */
    private void addConflictIfDifferent(List<FieldConflict> conflicts, String field, String fieldLabel,
                                        String localValue, String remoteValue) {
        // 如果远程值为空，不视为冲突
        if (StringUtils.isBlank(remoteValue)) {
            return;
        }
        // 如果本地值为空，不视为冲突（直接更新）
        if (StringUtils.isBlank(localValue)) {
            return;
        }
        // 如果值相同，不是冲突
        if (Objects.equals(localValue, remoteValue)) {
            return;
        }
        
        conflicts.add(FieldConflict.builder()
                .field(field)
                .fieldLabel(fieldLabel)
                .localValue(localValue)
                .remoteValue(remoteValue)
                .build());
    }
}
