package cn.cordys.crm.integration.service;

import cn.cordys.common.uid.IDGenerator;
import cn.cordys.security.SessionUtils;
import cn.cordys.crm.customer.domain.Customer;
import cn.cordys.crm.integration.domain.EnterpriseProfile;
import cn.cordys.crm.integration.dto.request.EnterpriseImportRequest;
import cn.cordys.crm.integration.dto.response.EnterpriseImportResponse;
import cn.cordys.crm.integration.dto.response.EnterpriseImportResponse.FieldConflict;
import cn.cordys.crm.integration.mapper.ExtEnterpriseProfileMapper;
import cn.cordys.crm.integration.service.IqichaSearchService.EnterpriseItem;
import cn.cordys.crm.integration.service.IqichaSearchService.SearchResult;
import cn.cordys.crm.integration.util.CreditCodeNormalizer;
import cn.cordys.mybatis.BaseMapper;
import jakarta.annotation.Resource;
import lombok.extern.slf4j.Slf4j;
import org.apache.commons.lang3.StringUtils;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
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
@Slf4j
@Service
public class EnterpriseService {

    @Resource
    private BaseMapper<EnterpriseProfile> enterpriseProfileMapper;

    @Resource
    private BaseMapper<Customer> customerMapper;

    @Resource
    private ExtEnterpriseProfileMapper extEnterpriseProfileMapper;

    @Resource
    private IqichaSearchService iqichaSearchService;

    @Resource
    private CreditCodeNormalizer creditCodeNormalizer;

    /**
     * 导入企业信息
     * 
     * @param request 导入请求
     * @param organizationId 组织ID
     * @return 导入结果
     */
    @Transactional(rollbackFor = Exception.class)
    public EnterpriseImportResponse importEnterprise(EnterpriseImportRequest request, String organizationId) {
        // 0. 规范化信用代码
        String originalCreditCode = request.getCreditCode();
        String normalizedCreditCode = creditCodeNormalizer.normalize(originalCreditCode);
        request.setCreditCode(normalizedCreditCode);
        
        if (!Objects.equals(originalCreditCode, normalizedCreditCode)) {
            log.info("Credit code normalized: '{}' -> '{}'", originalCreditCode, normalizedCreditCode);
        }
        
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
        // 规范化信用代码
        String originalCreditCode = request.getCreditCode();
        String normalizedCreditCode = creditCodeNormalizer.normalize(originalCreditCode);
        request.setCreditCode(normalizedCreditCode);
        
        if (!Objects.equals(originalCreditCode, normalizedCreditCode)) {
            log.info("Credit code normalized (force import): '{}' -> '{}'", originalCreditCode, normalizedCreditCode);
        }
        
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
     * 仅搜索本地数据库（enterprise_profile），不调用爱企查。
     * 用于 Flutter 端先查本地，无结果再由客户端自行请求爱企查。
     *
     * @param keyword 搜索关键词
     * @param page 页码
     * @param pageSize 每页数量
     * @param organizationId 组织ID
     * @return 搜索结果
     */
    public SearchResult searchLocalEnterprise(String keyword, int page, int pageSize, String organizationId) {
        // 参数校验
        if (StringUtils.isBlank(keyword) || keyword.trim().length() < 2) {
            return SearchResult.error("搜索关键词至少需要2个字符");
        }

        int safePage = Math.max(page, 1);
        int safePageSize = pageSize > 0 ? Math.min(pageSize, 50) : 10;
        int offset = (safePage - 1) * safePageSize;

        List<EnterpriseItem> items = new ArrayList<>();

        // 只查本地数据库
        if (StringUtils.isNotBlank(organizationId)) {
            long totalCount = extEnterpriseProfileMapper.countByCompanyName(keyword, organizationId);
            if (totalCount <= 0) {
                return SearchResult.success(items, 0);
            }

            List<EnterpriseProfile> localProfiles = extEnterpriseProfileMapper.searchByCompanyName(
                    keyword, organizationId, offset, safePageSize);
            if (localProfiles != null && !localProfiles.isEmpty()) {
                log.info("本地搜索 '{}' 找到 {} 条记录 (第{}页)", keyword, totalCount, safePage);

                for (EnterpriseProfile profile : localProfiles) {
                    items.add(toLocalEnterpriseItem(profile));
                }
            }

            return SearchResult.success(items, (int) Math.min(totalCount, Integer.MAX_VALUE));
        }

        // 本地无数据，返回空结果（success=true，items=[]）
        return SearchResult.success(items, 0);
    }

    /**
     * 企业搜索：混合搜索本地数据库和爱企查，所有页都查询并合并去重。
     *
     * 搜索策略：
     * - 所有页：同时查询本地和爱企查对应页
     * - 按信用代码去重，本地优先
     * - 返回合并后的结果
     *
     * 返回结果中每条记录带来源标识：
     * - local：本地数据库
     * - iqicha：爱企查
     *
     * @param keyword 搜索关键词
     * @param page 页码
     * @param pageSize 每页数量
     * @param organizationId 组织ID
     * @return 搜索结果
     */
    public SearchResult searchEnterprise(String keyword, int page, int pageSize, String organizationId) {
        // 参数校验
        if (StringUtils.isBlank(keyword) || keyword.trim().length() < 2) {
            return SearchResult.error("搜索关键词至少需要2个字符");
        }

        int safePage = Math.max(page, 1);
        int safePageSize = pageSize > 0 ? Math.min(pageSize, 50) : 10;
        int offset = (safePage - 1) * safePageSize;

        // 每一页都查询本地 + 爱企查，然后合并去重（本地优先）
        List<EnterpriseItem> items = new ArrayList<>();
        java.util.Set<String> seenCreditCodes = new java.util.HashSet<>();
        long localTotal = 0L;

        // 1) 本地：SQL 分页查询
        if (StringUtils.isNotBlank(organizationId)) {
            localTotal = extEnterpriseProfileMapper.countByCompanyName(keyword, organizationId);
            List<EnterpriseProfile> localProfiles = extEnterpriseProfileMapper.searchByCompanyName(
                    keyword, organizationId, offset, safePageSize);
            if (localProfiles != null && !localProfiles.isEmpty()) {
                log.info("本地搜索 '{}' 第{}页找到 {} 条记录", keyword, safePage, localProfiles.size());

                for (EnterpriseProfile profile : localProfiles) {
                    EnterpriseItem item = toLocalEnterpriseItem(profile);
                    items.add(item);
                    
                    // 记录信用代码用于去重
                    if (StringUtils.isNotBlank(item.getCreditCode())) {
                        seenCreditCodes.add(item.getCreditCode());
                    }
                }
            }
        }

        // 2) 爱企查：同页查询并合并去重（本地优先）
        SearchResult remote = iqichaSearchService.searchEnterprise(keyword, safePage, safePageSize);
        if (remote != null && remote.isSuccess() && remote.getItems() != null) {
            log.info("远程搜索 '{}' 第{}页找到 {} 条记录", keyword, safePage, remote.getItems().size());
            
            for (EnterpriseItem remoteItem : remote.getItems()) {
                // 限制结果大小不超过 pageSize
                if (items.size() >= safePageSize) {
                    break;
                }
                
                // 按信用代码去重（本地优先）
                String creditCode = remoteItem.getCreditCode();
                if (StringUtils.isNotBlank(creditCode) && seenCreditCodes.contains(creditCode)) {
                    log.debug("跳过重复企业: {} ({})", remoteItem.getName(), creditCode);
                    continue;
                }

                items.add(remoteItem);
                if (StringUtils.isNotBlank(creditCode)) {
                    seenCreditCodes.add(creditCode);
                }
            }

            // 使用远程 total 作为总数（远程通常有更多数据）
            // 安全转换 long to int，避免溢出
            int total = (int) Math.min((long) remote.getTotal(), Integer.MAX_VALUE);
            return SearchResult.success(items, total);
        } else if (remote != null && !remote.isSuccess()) {
            // 爱企查失败但本地有结果：返回本地结果
            if (!items.isEmpty()) {
                log.warn("爱企查搜索失败，返回本地结果: {}", remote.getMessage());
                return SearchResult.success(items, (int) Math.min(localTotal, Integer.MAX_VALUE));
            }
            return remote;
        }

        // 只有本地结果
        return SearchResult.success(items, (int) Math.min(localTotal, Integer.MAX_VALUE));
    }

    /**
     * 将本地企业档案转换为搜索结果项
     */
    private EnterpriseItem toLocalEnterpriseItem(EnterpriseProfile profile) {
        EnterpriseItem item = new EnterpriseItem();
        item.setSource("local");
        if (profile == null) {
            return item;
        }
        // 优先使用 iqichaId，如果为空则使用 id 作为备选（确保 pid 不为空）
        String pid = profile.getIqichaId();
        if (StringUtils.isBlank(pid)) {
            pid = profile.getId();
        }
        item.setPid(pid);
        item.setName(profile.getCompanyName());
        item.setCreditCode(profile.getCreditCode());
        item.setLegalPerson(profile.getLegalPerson());
        item.setAddress(profile.getAddress());
        item.setStatus(profile.getStatus());
        if (profile.getRegCapital() != null) {
            item.setRegisteredCapital(profile.getRegCapital().toPlainString());
        }
        if (profile.getRegDate() != null) {
            item.setEstablishDate(profile.getRegDate().format(DateTimeFormatter.ISO_LOCAL_DATE));
        }
        return item;
    }

    /**
     * 将时间戳（毫秒）转换为 LocalDate
     */
    private LocalDate convertTimestampToLocalDate(Long epochMilli) {
        if (epochMilli == null) {
            return null;
        }
        try {
            return Instant.ofEpochMilli(epochMilli)
                    .atZone(ZoneId.systemDefault())
                    .toLocalDate();
        } catch (Exception e) {
            log.warn("Failed to convert timestamp {} to LocalDate", epochMilli, e);
            return null;
        }
    }

    /**
     * 将时间戳转换为 ISO 日期格式
     */
    private String formatEpochMilliToIsoDate(Long epochMilli) {
        try {
            return Instant.ofEpochMilli(epochMilli)
                    .atZone(ZoneId.systemDefault())
                    .toLocalDate()
                    .format(DateTimeFormatter.ISO_LOCAL_DATE);
        } catch (Exception e) {
            return String.valueOf(epochMilli);
        }
    }

    /**
     * 创建新的企业档案和对应的客户记录
     */
    private EnterpriseProfile createEnterpriseProfile(EnterpriseImportRequest request, String organizationId) {
        EnterpriseProfile profile = new EnterpriseProfile();
        profile.setId(IDGenerator.nextStr());
        
        // 生成客户ID
        String customerId;
        if (StringUtils.isNotBlank(request.getCustomerId())) {
            customerId = request.getCustomerId();
        } else {
            customerId = IDGenerator.nextStr();
        }
        profile.setCustomerId(customerId);
        
        copyRequestToProfile(request, profile);
        profile.setOrganizationId(organizationId);
        profile.setCreateTime(System.currentTimeMillis());
        profile.setUpdateTime(System.currentTimeMillis());
        profile.setCreateUser(SessionUtils.getUserId());
        profile.setUpdateUser(SessionUtils.getUserId());
        profile.setLastSyncAt(System.currentTimeMillis());
        
        // 创建对应的客户记录
        Customer customer = new Customer();
        customer.setId(customerId);
        customer.setName(request.getCompanyName());
        customer.setOwner(SessionUtils.getUserId());
        customer.setCollectionTime(System.currentTimeMillis());
        customer.setInSharedPool(false);
        customer.setOrganizationId(organizationId);
        customer.setCreateTime(System.currentTimeMillis());
        customer.setUpdateTime(System.currentTimeMillis());
        customer.setCreateUser(SessionUtils.getUserId());
        customer.setUpdateUser(SessionUtils.getUserId());
        
        // 先插入客户记录，再插入企业档案（因为企业档案引用客户ID）
        customerMapper.insert(customer);
        // 使用显式的 insert 方法，确保 LocalDate 正确转换为 DATE
        extEnterpriseProfileMapper.insertWithDateConversion(profile);
        
        log.info("创建新客户和企业档案: customerId={}, profileId={}, companyName={}", 
                customerId, profile.getId(), request.getCompanyName());
        
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
        
        // 使用显式的 update 方法，确保 LocalDate 正确转换为 DATE
        extEnterpriseProfileMapper.updateWithDateConversion(existing);
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
            // 将时间戳（毫秒）转换为 LocalDate
            profile.setRegDate(convertTimestampToLocalDate(request.getEstablishmentDate()));
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
