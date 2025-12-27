package cn.cordys.crm.integration.service;

import cn.cordys.common.uid.IDGenerator;
import cn.cordys.crm.integration.domain.AiModelPricing;
import cn.cordys.crm.integration.mapper.AiModelPricingMapper;
import cn.cordys.security.SessionUtils;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.Resource;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.List;
import java.util.concurrent.ConcurrentHashMap;

/**
 * AI模型定价服务
 * 提供定价配置管理和缓存功能
 * 
 * Requirements: 2.1, 2.3, 4.1, 4.2, 4.3, 4.4, 6.1, 6.2, 6.3
 * 
 * @author cordys
 * @date 2025-12-27
 */
@Slf4j
@Service
public class AiModelPricingService {
    
    @Resource
    private AiModelPricingMapper pricingMapper;
    
    /**
     * Fallback 输入价格 (USD per 1000 tokens)
     */
    @Value("${ai.pricing.fallback.input:0.01}")
    private BigDecimal fallbackInputPrice;
    
    /**
     * Fallback 输出价格 (USD per 1000 tokens)
     */
    @Value("${ai.pricing.fallback.output:0.01}")
    private BigDecimal fallbackOutputPrice;
    
    /**
     * 定价缓存 (key: provider:model, value: AiModelPricing)
     * 使用 ConcurrentHashMap 保证线程安全
     */
    private final ConcurrentHashMap<String, AiModelPricing> pricingCache = new ConcurrentHashMap<>();
    
    /**
     * 初始化缓存
     * 在服务启动时加载所有启用的定价配置到内存
     * 
     * Property 4: Cache Initialization
     * For any number of pricing configs in database:
     * cache size should equal number of active configs
     * 
     * Requirements: 4.1
     */
    @PostConstruct
    public void initialize() {
        try {
            log.info("初始化 AI 模型定价缓存...");
            refreshCache();
            log.info("AI 模型定价缓存初始化完成，共加载 {} 条配置", pricingCache.size());
        } catch (Exception e) {
            log.error("初始化 AI 模型定价缓存失败", e);
            // 不抛出异常，允许服务启动，使用 fallback 定价
        }
    }
    
    /**
     * 刷新缓存
     * 每小时自动刷新一次，或手动调用
     * 
     * Requirements: 4.2, 4.3
     */
    @Scheduled(fixedRate = 3600000) // 1 hour = 3600000 ms
    public void refreshCache() {
        try {
            log.debug("开始刷新 AI 模型定价缓存...");
            
            List<AiModelPricing> allPricing = pricingMapper.selectAllActive();
            
            // 清空旧缓存
            pricingCache.clear();
            
            // 加载新数据
            if (allPricing != null) {
                for (AiModelPricing pricing : allPricing) {
                    pricingCache.put(pricing.getCacheKey(), pricing);
                }
            }
            
            log.debug("AI 模型定价缓存刷新完成，当前缓存 {} 条配置", pricingCache.size());
        } catch (Exception e) {
            log.error("刷新 AI 模型定价缓存失败", e);
        }
    }
    
    /**
     * 获取定价配置
     * 优先从缓存获取，如果不存在则返回 fallback 定价
     * 
     * Property 1: Pricing Lookup Accuracy
     * For any provider and model in database:
     * returned pricing should match database values
     * 
     * Property 6: Fallback Pricing
     * For any provider and model NOT in database:
     * should return fallback pricing with warning logged
     * 
     * Requirements: 2.1, 2.3, 6.1, 6.2, 6.3
     * 
     * @param providerCode 提供商代码
     * @param modelCode 模型代码
     * @return 定价配置
     */
    public AiModelPricing getPricing(String providerCode, String modelCode) {
        String cacheKey = providerCode + ":" + modelCode;
        
        AiModelPricing pricing = pricingCache.get(cacheKey);
        
        if (pricing != null) {
            return pricing;
        }
        
        // 缓存未命中，返回 fallback 定价
        log.warn("未找到模型定价配置: provider={}, model={}, 使用 fallback 定价", 
                providerCode, modelCode);
        
        return createFallbackPricing(providerCode, modelCode);
    }
    
    /**
     * 创建 fallback 定价配置
     * 
     * Requirements: 6.1, 6.2, 6.3
     * 
     * @param providerCode 提供商代码
     * @param modelCode 模型代码
     * @return fallback 定价配置
     */
    private AiModelPricing createFallbackPricing(String providerCode, String modelCode) {
        AiModelPricing fallback = new AiModelPricing();
        fallback.setProviderCode(providerCode);
        fallback.setModelCode(modelCode);
        fallback.setModelName(modelCode);
        fallback.setInputPrice(fallbackInputPrice);
        fallback.setOutputPrice(fallbackOutputPrice);
        fallback.setUnit(1000);
        fallback.setCurrency("USD");
        fallback.setEnabled(true);
        fallback.setDescription("Fallback pricing (not configured in database)");
        return fallback;
    }
    
    /**
     * 创建定价配置
     * 
     * Requirements: 8.1
     * 
     * @param pricing 定价配置
     * @return 创建的定价配置
     */
    public AiModelPricing createPricing(AiModelPricing pricing) {
        // 设置ID和时间戳
        pricing.setId(IDGenerator.nextStr());
        pricing.setCreateTime(System.currentTimeMillis());
        pricing.setUpdateTime(System.currentTimeMillis());
        pricing.setCreateUser(SessionUtils.getUserId());
        pricing.setUpdateUser(SessionUtils.getUserId());
        
        // 插入数据库
        pricingMapper.insert(pricing);
        
        // 刷新缓存
        refreshCache();
        
        log.info("创建 AI 模型定价配置: provider={}, model={}", 
                pricing.getProviderCode(), pricing.getModelCode());
        
        return pricing;
    }
    
    /**
     * 更新定价配置
     * 
     * Requirements: 8.3
     * 
     * @param pricing 定价配置
     * @return 更新的定价配置
     */
    public AiModelPricing updatePricing(AiModelPricing pricing) {
        // 更新时间戳
        pricing.setUpdateTime(System.currentTimeMillis());
        pricing.setUpdateUser(SessionUtils.getUserId());
        
        // 更新数据库
        pricingMapper.update(pricing);
        
        // 刷新缓存
        refreshCache();
        
        log.info("更新 AI 模型定价配置: provider={}, model={}", 
                pricing.getProviderCode(), pricing.getModelCode());
        
        return pricing;
    }
    
    /**
     * 获取所有定价配置
     * 
     * Requirements: 8.1
     * 
     * @return 所有启用的定价配置
     */
    public List<AiModelPricing> getAllPricing() {
        return pricingMapper.selectAllActive();
    }
    
    /**
     * 删除定价配置
     * 
     * Requirements: 8.4
     * 
     * @param id 定价配置ID
     */
    public void deletePricing(String id) {
        pricingMapper.deleteById(id);
        
        // 刷新缓存
        refreshCache();
        
        log.info("删除 AI 模型定价配置: id={}", id);
    }
}
