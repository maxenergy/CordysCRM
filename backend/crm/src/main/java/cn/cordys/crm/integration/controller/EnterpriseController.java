package cn.cordys.crm.integration.controller;

import cn.cordys.context.OrganizationContext;
import cn.cordys.crm.integration.domain.EnterpriseProfile;
import cn.cordys.crm.integration.dto.request.EnterpriseImportRequest;
import cn.cordys.crm.integration.dto.response.EnterpriseImportResponse;
import cn.cordys.crm.integration.service.EnterpriseService;
import cn.cordys.crm.integration.service.IntegrationConfigService;
import cn.cordys.crm.integration.service.IqichaSearchService;
import cn.cordys.crm.integration.service.IqichaSearchService.SearchResult;
import cn.cordys.crm.integration.service.IqichaSearchService.EnterpriseDetail;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.annotation.Resource;
import jakarta.validation.Valid;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * 企业信息导入控制器
 * 
 * Requirements: 2.4, 3.6
 * 
 * @author cordys
 * @date 2025-12-10
 */
@Slf4j
@Tag(name = "企业信息导入")
@RestController
@RequestMapping("/api/enterprise")
public class EnterpriseController {

    @Resource
    private EnterpriseService enterpriseService;

    @Resource
    private IqichaSearchService iqichaSearchService;

    @Resource(name = "aiIntegrationConfigService")
    private IntegrationConfigService integrationConfigService;

    /**
     * 导入企业信息
     * 从爱企查导入企业工商信息到CRM
     * 
     * @param request 导入请求
     * @return 导入结果
     */
    @PostMapping("/import")
    @Operation(summary = "导入企业信息", description = "从爱企查导入企业工商信息到CRM，支持Chrome Extension和WebView调用")
    public EnterpriseImportResponse importEnterprise(@Valid @RequestBody EnterpriseImportRequest request) {
        String organizationId = OrganizationContext.getOrganizationId();
        return enterpriseService.importEnterprise(request, organizationId);
    }

    /**
     * 强制导入企业信息（覆盖冲突）
     * 
     * @param request 导入请求
     * @return 导入结果
     */
    @PostMapping("/import/force")
    @Operation(summary = "强制导入企业信息", description = "强制导入企业信息，覆盖已有数据")
    public EnterpriseImportResponse forceImportEnterprise(@Valid @RequestBody EnterpriseImportRequest request) {
        String organizationId = OrganizationContext.getOrganizationId();
        return enterpriseService.forceImportEnterprise(request, organizationId);
    }

    /**
     * 检查企业是否已存在
     * 
     * @param creditCode 统一社会信用代码
     * @return 是否存在
     */
    @GetMapping("/check/{creditCode}")
    @Operation(summary = "检查企业是否已存在", description = "根据统一社会信用代码检查企业是否已导入")
    public boolean checkExists(@PathVariable String creditCode) {
        String organizationId = OrganizationContext.getOrganizationId();
        return enterpriseService.checkDuplicate(creditCode, organizationId);
    }

    /**
     * 根据客户ID获取企业档案
     * 
     * @param customerId 客户ID
     * @return 企业档案
     */
    @GetMapping("/profile/{customerId}")
    @Operation(summary = "获取企业档案", description = "根据客户ID获取企业工商信息档案")
    public EnterpriseProfile getProfile(@PathVariable String customerId) {
        return enterpriseService.findByCustomerId(customerId);
    }

    /**
     * 根据统一社会信用代码获取企业档案
     * 
     * @param creditCode 统一社会信用代码
     * @return 企业档案
     */
    @GetMapping("/profile/credit/{creditCode}")
    @Operation(summary = "根据信用代码获取企业档案", description = "根据统一社会信用代码获取企业工商信息档案")
    public EnterpriseProfile getProfileByCreditCode(@PathVariable String creditCode) {
        String organizationId = OrganizationContext.getOrganizationId();
        return enterpriseService.findByCreditCode(creditCode, organizationId);
    }

    /**
     * 搜索爱企查企业
     * 
     * @param keyword 搜索关键词
     * @param page 页码（默认1）
     * @param pageSize 每页数量（默认10）
     * @return 搜索结果
     */
    @GetMapping("/search")
    @Operation(summary = "搜索爱企查企业", description = "通过爱企查搜索企业信息")
    public SearchResult searchEnterprise(
            @RequestParam String keyword,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int pageSize) {
        return iqichaSearchService.searchEnterprise(keyword, page, pageSize);
    }

    /**
     * 获取爱企查企业详情
     * 
     * @param pid 爱企查企业ID
     * @return 企业详情
     */
    @GetMapping("/detail/{pid}")
    @Operation(summary = "获取爱企查企业详情", description = "根据爱企查企业ID获取详细信息")
    public EnterpriseDetail getEnterpriseDetail(@PathVariable String pid) {
        return iqichaSearchService.getEnterpriseDetail(pid);
    }

    /**
     * 测试端点 - 用于验证路由是否正确注册
     */
    @GetMapping("/config/test")
    @Operation(summary = "测试端点", description = "用于验证路由是否正确注册")
    public Map<String, Object> testEndpoint() {
        log.info("[DEBUG] 测试端点被调用");
        return Map.of("success", true, "message", "路由正常", "timestamp", System.currentTimeMillis());
    }

    /**
     * 保存爱企查 Cookie
     * 
     * @param request 包含 cookie 字段的请求体
     * @return 保存结果
     */
    @PostMapping("/config/cookie")
    @Operation(summary = "保存爱企查Cookie", description = "保存爱企查登录Cookie用于企业搜索")
    public Map<String, Object> saveIqichaCookie(@RequestBody(required = false) Map<String, String> request) {
        log.info("[DEBUG] saveIqichaCookie 方法被调用, request={}", request);
        try {
            // 验证请求参数
            if (request == null) {
                log.warn("保存爱企查Cookie失败: 请求参数为空");
                return Map.of("success", false, "message", "请求参数不能为空");
            }
            
            String cookie = request.get("cookie");
            if (cookie == null || cookie.isBlank()) {
                log.warn("保存爱企查Cookie失败: Cookie为空");
                return Map.of("success", false, "message", "Cookie 不能为空");
            }
            
            // 获取组织ID
            String organizationId;
            try {
                organizationId = OrganizationContext.getOrganizationId();
            } catch (Exception e) {
                log.warn("保存爱企查Cookie失败: 无法获取组织信息 - {}", e.getMessage());
                return Map.of("success", false, "message", "无法获取组织信息，请重新登录");
            }
            
            if (organizationId == null || organizationId.isBlank()) {
                log.warn("保存爱企查Cookie失败: 组织ID为空");
                return Map.of("success", false, "message", "无法获取组织信息，请重新登录");
            }
            
            // 保存Cookie
            integrationConfigService.saveIqichaCookie(cookie, organizationId);
            log.info("保存爱企查Cookie成功, organizationId={}", organizationId);
            return Map.of("success", true, "message", "保存成功");
        } catch (Exception e) {
            log.error("保存爱企查Cookie失败", e);
            String errorMsg = e.getMessage();
            if (errorMsg == null || errorMsg.isBlank()) {
                errorMsg = e.getClass().getSimpleName();
            }
            return Map.of("success", false, "message", "保存失败: " + errorMsg);
        }
    }

    /**
     * 检查爱企查 Cookie 是否已配置
     * 
     * @return 配置状态
     */
    @GetMapping("/config/cookie/status")
    @Operation(summary = "检查爱企查Cookie状态", description = "检查是否已配置爱企查Cookie")
    public Map<String, Object> checkIqichaCookieStatus() {
        String organizationId = OrganizationContext.getOrganizationId();
        boolean configured = integrationConfigService.hasConfig(
            IntegrationConfigService.KEY_IQICHA_COOKIE, organizationId);
        return Map.of("configured", configured);
    }
}
