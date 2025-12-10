package cn.cordys.crm.integration.controller;

import cn.cordys.context.OrganizationContext;
import cn.cordys.crm.integration.dto.request.PortraitGenerateRequest;
import cn.cordys.crm.integration.dto.response.PortraitResponse;
import cn.cordys.crm.integration.service.PortraitService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.annotation.Resource;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

/**
 * AI 画像控制器
 * 
 * Requirements: 5.2, 5.4
 * 
 * @author cordys
 * @date 2025-12-10
 */
@RestController
@RequestMapping("/api/ai/portrait")
@Tag(name = "AI画像", description = "AI企业画像生成与查询")
public class PortraitController {

    @Resource
    private PortraitService portraitService;

    /**
     * 生成企业画像
     * 
     * @param request 生成请求
     * @return 画像响应
     */
    @PostMapping("/generate")
    @Operation(summary = "生成企业画像", description = "根据客户ID生成AI企业画像")
    public PortraitResponse generatePortrait(@Valid @RequestBody PortraitGenerateRequest request) {
        String organizationId = OrganizationContext.getOrganizationId();
        boolean forceRefresh = Boolean.TRUE.equals(request.getForceRefresh());
        
        return portraitService.generatePortrait(
                request.getCustomerId(), 
                forceRefresh, 
                organizationId
        );
    }

    /**
     * 获取企业画像
     * 
     * @param customerId 客户ID
     * @return 画像响应
     */
    @GetMapping("/{customerId}")
    @Operation(summary = "获取企业画像", description = "根据客户ID获取已生成的企业画像")
    public PortraitResponse getPortrait(
            @Parameter(description = "客户ID", required = true)
            @PathVariable String customerId) {
        
        return portraitService.getPortrait(customerId);
    }
}
