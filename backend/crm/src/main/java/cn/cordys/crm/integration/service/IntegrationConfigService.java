package cn.cordys.crm.integration.service;

import cn.cordys.common.uid.IDGenerator;
import cn.cordys.security.SessionUtils;
import cn.cordys.crm.integration.domain.IntegrationConfig;
import cn.cordys.crm.integration.mapper.ExtIntegrationConfigMapper;
import cn.cordys.mybatis.BaseMapper;
import jakarta.annotation.Resource;
import org.apache.commons.lang3.StringUtils;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

/**
 * 集成配置服务
 * 管理第三方服务的连接参数，支持加密存储敏感配置
 * 
 * Requirements: 8.1, 8.2, 8.3, 8.4
 * 
 * @author cordys
 * @date 2025-12-10
 */
@Service
public class IntegrationConfigService {

    /**
     * 配置键常量
     */
    public static final String KEY_IQICHA_COOKIE = "iqicha.cookie";
    public static final String KEY_IQICHA_SESSION = "iqicha.session";
    public static final String KEY_AI_PROVIDER = "ai.provider";
    public static final String KEY_AI_MODEL = "ai.model";
    public static final String KEY_AI_API_KEY = "ai.api_key";
    public static final String KEY_AI_TEMPERATURE = "ai.temperature";
    public static final String KEY_AI_MAX_TOKENS = "ai.max_tokens";
    public static final String KEY_AI_BASE_URL = "ai.base_url";

    @Resource
    private BaseMapper<IntegrationConfig> configMapper;

    @Resource
    private ExtIntegrationConfigMapper extConfigMapper;

    @Resource
    private EncryptionService encryptionService;

    /**
     * 获取配置值
     *
     * @param configKey      配置键
     * @param organizationId 组织ID
     * @return 配置值（如果是加密的会自动解密）
     */
    public Optional<String> getConfig(String configKey, String organizationId) {
        IntegrationConfig config = extConfigMapper.selectByKey(configKey, organizationId);
        if (config == null) {
            return Optional.empty();
        }

        String value = config.getConfigValue();
        if (Boolean.TRUE.equals(config.getEncrypted()) && StringUtils.isNotBlank(value)) {
            value = encryptionService.decrypt(value);
        }
        return Optional.ofNullable(value);
    }

    /**
     * 获取配置值，如果不存在则返回默认值
     *
     * @param configKey      配置键
     * @param organizationId 组织ID
     * @param defaultValue   默认值
     * @return 配置值
     */
    public String getConfig(String configKey, String organizationId, String defaultValue) {
        return getConfig(configKey, organizationId).orElse(defaultValue);
    }

    /**
     * 保存配置（自动判断是否需要加密）
     *
     * @param configKey      配置键
     * @param configValue    配置值
     * @param organizationId 组织ID
     * @param description    描述
     */
    @Transactional(rollbackFor = Exception.class)
    public void saveConfig(String configKey, String configValue, String organizationId, String description) {
        boolean shouldEncrypt = isSensitiveConfig(configKey);
        saveConfig(configKey, configValue, organizationId, description, shouldEncrypt);
    }

    /**
     * 保存配置
     *
     * @param configKey      配置键
     * @param configValue    配置值
     * @param organizationId 组织ID
     * @param description    描述
     * @param encrypt        是否加密
     */
    @Transactional(rollbackFor = Exception.class)
    public void saveConfig(String configKey, String configValue, String organizationId, 
                          String description, boolean encrypt) {
        String valueToStore = configValue;
        if (encrypt && StringUtils.isNotBlank(configValue)) {
            valueToStore = encryptionService.encrypt(configValue);
        }

        IntegrationConfig config = new IntegrationConfig();
        config.setId(IDGenerator.nextStr());
        config.setConfigKey(configKey);
        config.setConfigValue(valueToStore);
        config.setEncrypted(encrypt);
        config.setOrganizationId(organizationId);
        config.setDescription(description);
        config.setCreateTime(System.currentTimeMillis());
        config.setUpdateTime(System.currentTimeMillis());
        config.setCreateUser(SessionUtils.getUserId());
        config.setUpdateUser(SessionUtils.getUserId());

        extConfigMapper.upsert(config);
    }

    /**
     * 删除配置
     *
     * @param configKey      配置键
     * @param organizationId 组织ID
     */
    @Transactional(rollbackFor = Exception.class)
    public void deleteConfig(String configKey, String organizationId) {
        IntegrationConfig config = extConfigMapper.selectByKey(configKey, organizationId);
        if (config != null) {
            configMapper.deleteByPrimaryKey(config.getId());
        }
    }

    /**
     * 获取组织的所有配置
     *
     * @param organizationId 组织ID
     * @return 配置列表（敏感配置值会被脱敏）
     */
    public List<IntegrationConfig> listConfigs(String organizationId) {
        List<IntegrationConfig> configs = extConfigMapper.selectByOrganization(organizationId);
        // 脱敏处理
        configs.forEach(config -> {
            if (Boolean.TRUE.equals(config.getEncrypted())) {
                config.setConfigValue("******");
            }
        });
        return configs;
    }

    /**
     * 检查配置是否存在
     *
     * @param configKey      配置键
     * @param organizationId 组织ID
     * @return 是否存在
     */
    public boolean hasConfig(String configKey, String organizationId) {
        return extConfigMapper.selectByKey(configKey, organizationId) != null;
    }

    /**
     * 判断是否为敏感配置（需要加密存储）
     *
     * @param configKey 配置键
     * @return 是否敏感
     */
    private boolean isSensitiveConfig(String configKey) {
        return configKey != null && (
                configKey.contains("cookie") ||
                configKey.contains("session") ||
                configKey.contains("api_key") ||
                configKey.contains("password") ||
                configKey.contains("secret") ||
                configKey.contains("token")
        );
    }

    // ==================== 便捷方法 ====================

    /**
     * 获取爱企查Cookie
     */
    public Optional<String> getIqichaCookie(String organizationId) {
        return getConfig(KEY_IQICHA_COOKIE, organizationId);
    }

    /**
     * 保存爱企查Cookie
     */
    public void saveIqichaCookie(String cookie, String organizationId) {
        saveConfig(KEY_IQICHA_COOKIE, cookie, organizationId, "爱企查登录Cookie", true);
    }

    /**
     * 获取AI服务提供商
     */
    public String getAIProvider(String organizationId) {
        return getConfig(KEY_AI_PROVIDER, organizationId, "openai");
    }

    /**
     * 获取AI模型名称
     */
    public String getAIModel(String organizationId) {
        return getConfig(KEY_AI_MODEL, organizationId, "gpt-4");
    }

    /**
     * 获取AI API Key
     */
    public Optional<String> getAIApiKey(String organizationId) {
        return getConfig(KEY_AI_API_KEY, organizationId);
    }

    /**
     * 保存AI配置
     */
    public void saveAIConfig(String provider, String model, String apiKey, 
                            String baseUrl, String organizationId) {
        saveConfig(KEY_AI_PROVIDER, provider, organizationId, "AI服务提供商", false);
        saveConfig(KEY_AI_MODEL, model, organizationId, "AI模型名称", false);
        saveConfig(KEY_AI_API_KEY, apiKey, organizationId, "AI API密钥", true);
        if (StringUtils.isNotBlank(baseUrl)) {
            saveConfig(KEY_AI_BASE_URL, baseUrl, organizationId, "AI服务地址", false);
        }
    }

    /**
     * 获取AI温度参数
     */
    public double getAITemperature(String organizationId) {
        String temp = getConfig(KEY_AI_TEMPERATURE, organizationId, "0.7");
        try {
            return Double.parseDouble(temp);
        } catch (NumberFormatException e) {
            return 0.7;
        }
    }

    /**
     * 获取AI最大Token数
     */
    public int getAIMaxTokens(String organizationId) {
        String tokens = getConfig(KEY_AI_MAX_TOKENS, organizationId, "2000");
        try {
            return Integer.parseInt(tokens);
        } catch (NumberFormatException e) {
            return 2000;
        }
    }
}
