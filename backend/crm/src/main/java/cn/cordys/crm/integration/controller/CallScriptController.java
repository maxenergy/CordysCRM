package cn.cordys.crm.integration.controller;

import cn.cordys.context.OrganizationContext;
import cn.cordys.crm.integration.domain.CallScriptTemplate;
import cn.cordys.crm.integration.dto.request.ScriptGenerateRequest;
import cn.cordys.crm.integration.dto.response.ScriptResponse;
import cn.cordys.crm.integration.service.CallScriptService;
import cn.cordys.crm.integration.service.CallScriptTemplateService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.annotation.Resource;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * AI 话术控制器
 * 
 * Requirements: 6.1, 6.5
 * 
 * @author cordys
 * @date 2025-12-10
 */
@RestController
@RequestMapping("/api/ai/script")
@Tag(name = "AI话术", description = "AI话术生成与管理")
public class CallScriptController {

    @Resource
    private CallScriptService callScriptService;

    @Resource
    private CallScriptTemplateService templateService;

    /**
     * 生成话术
     * 
     * @param request 生成请求
     * @return 话术响应
     */
    @PostMapping("/generate")
    @Operation(summary = "生成话术", description = "根据客户信息和参数生成AI话术")
    public ScriptResponse generateScript(@Valid @RequestBody ScriptGenerateRequest request) {
        String organizationId = OrganizationContext.getOrganizationId();
        return callScriptService.generateScript(request, organizationId);
    }

    /**
     * 获取话术历史
     * 
     * @param customerId 客户ID
     * @param limit 限制数量
     * @return 话术历史列表
     */
    @GetMapping("/history/{customerId}")
    @Operation(summary = "获取话术历史", description = "获取客户的话术生成历史")
    public List<ScriptResponse> getScriptHistory(
            @Parameter(description = "客户ID", required = true)
            @PathVariable String customerId,
            @Parameter(description = "限制数量")
            @RequestParam(defaultValue = "10") int limit) {
        return callScriptService.getScriptHistory(customerId, limit);
    }

    /**
     * 获取话术详情
     * 
     * @param scriptId 话术ID
     * @return 话术响应
     */
    @GetMapping("/{scriptId}")
    @Operation(summary = "获取话术详情", description = "根据ID获取话术详情")
    public ScriptResponse getScript(
            @Parameter(description = "话术ID", required = true)
            @PathVariable String scriptId) {
        return callScriptService.getById(scriptId);
    }

    /**
     * 更新话术内容
     * 
     * @param scriptId 话术ID
     * @param content 新内容
     * @return 更新后的话术
     */
    @PutMapping("/{scriptId}")
    @Operation(summary = "更新话术内容", description = "用户编辑话术内容后保存")
    public ScriptResponse updateScript(
            @Parameter(description = "话术ID", required = true)
            @PathVariable String scriptId,
            @RequestBody String content) {
        return callScriptService.updateContent(scriptId, content);
    }

    /**
     * 获取话术模板列表
     * 
     * @param industry 行业
     * @param scene 场景
     * @param channel 渠道
     * @return 模板列表
     */
    @GetMapping("/templates")
    @Operation(summary = "获取话术模板列表", description = "获取可用的话术模板")
    public List<CallScriptTemplate> getTemplates(
            @Parameter(description = "行业")
            @RequestParam(required = false) String industry,
            @Parameter(description = "场景")
            @RequestParam(required = false) String scene,
            @Parameter(description = "渠道")
            @RequestParam(required = false) String channel) {
        String organizationId = OrganizationContext.getOrganizationId();
        return templateService.getEnabledTemplates(industry, scene, channel, organizationId);
    }

    /**
     * 获取分组的模板列表
     * 
     * @return 按行业和场景分组的模板
     */
    @GetMapping("/templates/grouped")
    @Operation(summary = "获取分组的模板列表", description = "按行业和场景分组获取模板")
    public Map<String, Map<String, List<CallScriptTemplate>>> getGroupedTemplates() {
        String organizationId = OrganizationContext.getOrganizationId();
        return templateService.getGroupedTemplates(organizationId);
    }
}
