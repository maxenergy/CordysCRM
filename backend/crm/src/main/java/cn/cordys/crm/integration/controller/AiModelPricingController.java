package cn.cordys.crm.integration.controller;

import cn.cordys.common.uid.IDGenerator;
import cn.cordys.crm.integration.domain.AiModelPricing;
import cn.cordys.crm.integration.dto.request.AiModelPricingRequest;
import cn.cordys.crm.integration.dto.response.AiModelPricingResponse;
import cn.cordys.crm.integration.service.AiModelPricingService;
import cn.cordys.security.SessionUtils;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.annotation.Resource;
import jakarta.validation.Valid;
import org.springframework.beans.BeanUtils;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.stream.Collectors;

/**
 * AI Model Pricing Controller
 * 
 * Requirements: 8.1, 8.2, 8.3, 8.4, 8.5
 * 
 * @author cordys
 * @date 2025-12-27
 */
@RestController
@RequestMapping("/api/ai/pricing")
@Tag(name = "AI定价管理", description = "AI模型定价配置管理")
public class AiModelPricingController {

    @Resource
    private AiModelPricingService pricingService;

    /**
     * 获取所有定价配置
     * 
     * @return 定价配置列表
     */
    @GetMapping
    @Operation(summary = "获取所有定价配置", description = "获取所有AI模型定价配置")
    public List<AiModelPricingResponse> getAllPricing() {
        List<AiModelPricing> pricingList = pricingService.getAllPricing();
        return pricingList.stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    /**
     * 获取指定定价配置
     * 
     * @param provider 提供商代码
     * @param model 模型代码
     * @return 定价配置
     */
    @GetMapping("/{provider}/{model}")
    @Operation(summary = "获取指定定价配置", description = "根据提供商和模型获取定价配置")
    public AiModelPricingResponse getPricing(
            @Parameter(description = "提供商代码", required = true)
            @PathVariable String provider,
            @Parameter(description = "模型代码", required = true)
            @PathVariable String model) {
        
        AiModelPricing pricing = pricingService.getPricing(provider, model);
        return toResponse(pricing);
    }

    /**
     * 创建定价配置
     * 
     * @param request 定价配置请求
     * @return 创建的定价配置
     */
    @PostMapping
    @Operation(summary = "创建定价配置", description = "创建新的AI模型定价配置")
    public AiModelPricingResponse createPricing(@Valid @RequestBody AiModelPricingRequest request) {
        AiModelPricing pricing = toDomain(request);
        pricing.setId(IDGenerator.nextStr());
        pricing.setCreateTime(System.currentTimeMillis());
        pricing.setUpdateTime(System.currentTimeMillis());
        pricing.setCreateUser(SessionUtils.getUserId());
        pricing.setUpdateUser(SessionUtils.getUserId());
        
        pricingService.createPricing(pricing);
        return toResponse(pricing);
    }

    /**
     * 更新定价配置
     * 
     * @param id 定价配置ID
     * @param request 定价配置请求
     * @return 更新后的定价配置
     */
    @PutMapping("/{id}")
    @Operation(summary = "更新定价配置", description = "更新现有的AI模型定价配置")
    public AiModelPricingResponse updatePricing(
            @Parameter(description = "定价配置ID", required = true)
            @PathVariable String id,
            @Valid @RequestBody AiModelPricingRequest request) {
        
        AiModelPricing pricing = toDomain(request);
        pricing.setId(id);
        pricing.setUpdateTime(System.currentTimeMillis());
        pricing.setUpdateUser(SessionUtils.getUserId());
        
        pricingService.updatePricing(pricing);
        return toResponse(pricing);
    }

    /**
     * 删除定价配置
     * 
     * @param id 定价配置ID
     */
    @DeleteMapping("/{id}")
    @Operation(summary = "删除定价配置", description = "删除指定的AI模型定价配置")
    public void deletePricing(
            @Parameter(description = "定价配置ID", required = true)
            @PathVariable String id) {
        
        pricingService.deletePricing(id);
    }

    /**
     * 手动刷新缓存
     */
    @PostMapping("/refresh")
    @Operation(summary = "刷新定价缓存", description = "手动刷新AI模型定价缓存")
    public void refreshCache() {
        pricingService.refreshCache();
    }

    /**
     * 转换为响应DTO
     */
    private AiModelPricingResponse toResponse(AiModelPricing pricing) {
        AiModelPricingResponse response = new AiModelPricingResponse();
        BeanUtils.copyProperties(pricing, response);
        return response;
    }

    /**
     * 转换为领域对象
     */
    private AiModelPricing toDomain(AiModelPricingRequest request) {
        AiModelPricing pricing = new AiModelPricing();
        pricing.setProviderCode(request.getProviderCode());
        pricing.setModelCode(request.getModelCode());
        pricing.setInputPrice(request.getInputPrice());
        pricing.setOutputPrice(request.getOutputPrice());
        pricing.setCurrency(request.getCurrency());
        pricing.setUnit(request.getUnit() != null ? request.getUnit() : 1000);
        pricing.setEnabled(request.getIsActive() != null ? request.getIsActive() : true);
        return pricing;
    }
}
