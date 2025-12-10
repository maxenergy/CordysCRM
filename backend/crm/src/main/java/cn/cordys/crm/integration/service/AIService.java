package cn.cordys.crm.integration.service;

import cn.cordys.common.uid.IDGenerator;
import cn.cordys.security.SessionUtils;
import cn.cordys.crm.integration.ai.LLMProvider;
import cn.cordys.crm.integration.ai.LLMRequest;
import cn.cordys.crm.integration.ai.LLMResponse;
import cn.cordys.crm.integration.ai.ProviderType;
import cn.cordys.crm.integration.domain.AIGenerationLog;
import cn.cordys.crm.integration.mapper.ExtAIGenerationLogMapper;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.Resource;
import org.apache.commons.lang3.StringUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;

/**
 * AI 服务
 * 封装 LLM 调用，支持多 Provider
 * 
 * Requirements: 5.4, 5.5
 * 
 * @author cordys
 * @date 2025-12-10
 */
@Service
public class AIService {

    private static final Logger log = LoggerFactory.getLogger(AIService.class);

    @Resource
    private List<LLMProvider> providerList;

    @Resource
    private ExtAIGenerationLogMapper aiGenerationLogMapper;

    @Value("${ai.default-provider:local}")
    private String defaultProviderCode;

    private Map<ProviderType, LLMProvider> providers;

    @PostConstruct
    public void init() {
        providers = new EnumMap<>(ProviderType.class);
        for (LLMProvider provider : providerList) {
            providers.put(provider.getProviderType(), provider);
            log.info("Registered LLM provider: {}", provider.getProviderType());
        }
    }

    /**
     * 使用默认提供商生成 AI 响应
     * 
     * @param request LLM 请求
     * @param customerId 客户ID
     * @param scene 场景
     * @param organizationId 组织ID
     * @return LLM 响应
     */
    public LLMResponse generate(LLMRequest request, String customerId, String scene, String organizationId) {
        ProviderType providerType = ProviderType.fromCode(defaultProviderCode);
        return generateWithProvider(providerType, request, customerId, scene, organizationId);
    }

    /**
     * 使用指定提供商生成 AI 响应
     * 
     * Property 17: AI调用参数完整性
     * For any 画像生成请求，发送给 AI 服务的 Prompt 应该包含企业的基本信息
     * 
     * @param providerType 提供商类型
     * @param request LLM 请求
     * @param customerId 客户ID
     * @param scene 场景
     * @param organizationId 组织ID
     * @return LLM 响应
     */
    public LLMResponse generateWithProvider(ProviderType providerType, LLMRequest request, 
                                            String customerId, String scene, String organizationId) {
        LLMProvider provider = providers.get(providerType);
        if (provider == null) {
            log.error("Provider not found: {}", providerType);
            return LLMResponse.failure("Provider not supported: " + providerType);
        }

        if (!provider.isAvailable()) {
            log.warn("Provider not available: {}", providerType);
            return LLMResponse.failure("Provider not available: " + providerType);
        }

        // 创建日志记录
        AIGenerationLog logEntry = createLogEntry(customerId, scene, request, providerType, organizationId);
        long startTime = System.currentTimeMillis();

        try {
            // 调用 LLM
            LLMResponse response = provider.generate(request);
            long latency = System.currentTimeMillis() - startTime;

            // 更新日志
            updateLogSuccess(logEntry, response, latency);
            aiGenerationLogMapper.insert(logEntry);

            return response;
        } catch (Exception e) {
            long latency = System.currentTimeMillis() - startTime;
            log.error("AI generation failed for customer {}: {}", customerId, e.getMessage(), e);

            // 更新失败日志
            updateLogFailure(logEntry, e.getMessage(), latency);
            aiGenerationLogMapper.insert(logEntry);

            return LLMResponse.failure(e.getMessage());
        }
    }

    /**
     * 检查提供商是否可用
     */
    public boolean isProviderAvailable(ProviderType providerType) {
        LLMProvider provider = providers.get(providerType);
        return provider != null && provider.isAvailable();
    }

    /**
     * 获取默认提供商类型
     */
    public ProviderType getDefaultProviderType() {
        return ProviderType.fromCode(defaultProviderCode);
    }

    private AIGenerationLog createLogEntry(String customerId, String scene, LLMRequest request, 
                                           ProviderType providerType, String organizationId) {
        AIGenerationLog log = new AIGenerationLog();
        log.setId(IDGenerator.nextStr());
        log.setCustomerId(customerId);
        log.setScene(scene);
        log.setModel(request.getModel());
        log.setProvider(providerType.getCode());
        log.setPromptHash(computePromptHash(request.getPrompt()));
        log.setOrganizationId(organizationId);
        log.setCreateTime(System.currentTimeMillis());
        log.setCreateUser(SessionUtils.getUserId());
        return log;
    }

    private void updateLogSuccess(AIGenerationLog logEntry, LLMResponse response, long latency) {
        logEntry.setModel(response.getModel());
        logEntry.setTokensPrompt(response.getPromptTokens());
        logEntry.setTokensCompletion(response.getCompletionTokens());
        logEntry.setLatencyMs((int) latency);
        logEntry.setStatus("success");
        logEntry.setCost(calculateCost(response));
    }

    private void updateLogFailure(AIGenerationLog logEntry, String errorMsg, long latency) {
        logEntry.setLatencyMs((int) latency);
        logEntry.setStatus("failed");
        logEntry.setErrorMsg(StringUtils.abbreviate(errorMsg, 256));
    }

    private String computePromptHash(String prompt) {
        if (StringUtils.isBlank(prompt)) {
            return null;
        }
        try {
            java.security.MessageDigest md = java.security.MessageDigest.getInstance("SHA-256");
            byte[] hash = md.digest(prompt.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : hash) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (java.security.NoSuchAlgorithmException e) {
            return null;
        }
    }

    private BigDecimal calculateCost(LLMResponse response) {
        // 简单的成本估算：$0.01 / 1000 tokens
        int totalTokens = response.getTotalTokens();
        return BigDecimal.valueOf(totalTokens * 0.00001);
    }
}
