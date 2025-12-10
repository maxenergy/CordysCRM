package cn.cordys.crm.integration.controller;

import cn.cordys.context.OrganizationContext;
import cn.cordys.crm.integration.domain.EnterpriseProfile;
import cn.cordys.crm.integration.dto.request.EnterpriseImportRequest;
import cn.cordys.crm.integration.dto.response.EnterpriseImportResponse;
import cn.cordys.crm.integration.service.EnterpriseService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.annotation.Resource;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 企业信息导入控制器
 * 
 * Requirements: 2.4, 3.6
 * 
 * @author cordys
 * @date 2025-12-10
 */
@Tag(name = "企业信息导入")
@RestController
@RequestMapping("/api/enterprise")
public class EnterpriseController {

    @Resource
    private EnterpriseService enterpriseService;

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
}
