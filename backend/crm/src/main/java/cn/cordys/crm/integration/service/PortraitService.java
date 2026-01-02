package cn.cordys.crm.integration.service;

import cn.cordys.common.uid.IDGenerator;
import cn.cordys.common.util.JSON;
import cn.cordys.security.SessionUtils;
import cn.cordys.crm.integration.ai.LLMRequest;
import cn.cordys.crm.integration.ai.LLMResponse;
import cn.cordys.crm.integration.domain.CompanyPortrait;
import cn.cordys.crm.integration.domain.EnterpriseProfile;
import cn.cordys.crm.integration.dto.response.PortraitResponse;
import cn.cordys.crm.integration.dto.response.PortraitResponse.*;
import cn.cordys.crm.integration.mapper.ExtCompanyPortraitMapper;
import cn.cordys.mybatis.BaseMapper;
import jakarta.annotation.Resource;
import org.apache.commons.lang3.StringUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;

import java.util.*;

/**
 * 企业画像服务
 * 负责画像生成、解析和存储
 * 
 * Requirements: 5.4, 5.5, 5.6
 * 
 * @author cordys
 * @date 2025-12-10
 */
@Service
public class PortraitService {

    private static final Logger log = LoggerFactory.getLogger(PortraitService.class);

    private static final String SCENE_PORTRAIT = "portrait";
    private static final String DEFAULT_VERSION = "v1";
    private static final String SOURCE_AI = "ai";

    @Resource
    private AIService aiService;

    @Resource
    private EnterpriseService enterpriseService;

    @Resource
    private BaseMapper<CompanyPortrait> companyPortraitMapper;

    @Resource
    private ExtCompanyPortraitMapper extCompanyPortraitMapper;

    /**
     * 生成企业画像
     * 
     * @param customerId 客户ID
     * @param forceRefresh 是否强制刷新
     * @param organizationId 组织ID
     * @return 画像响应
     */
    @Transactional(rollbackFor = Exception.class)
    public PortraitResponse generatePortrait(String customerId, boolean forceRefresh, String organizationId) {
        // 1. 检查是否已有画像且不需要强制刷新
        if (!forceRefresh) {
            CompanyPortrait existing = extCompanyPortraitMapper.selectByCustomerId(customerId);
            if (existing != null) {
                log.info("Portrait already exists for customer {}, returning cached", customerId);
                return convertToResponse(existing);
            }
        }

        // 2. 获取企业档案
        EnterpriseProfile profile = enterpriseService.findByCustomerId(customerId);
        if (profile == null) {
            throw new IllegalArgumentException("企业档案不存在: customerId=" + customerId);
        }

        // 3. 构建 Prompt 并调用 AI
        String prompt = buildPrompt(profile);
        LLMRequest request = LLMRequest.builder()
                .prompt(prompt)
                .systemPrompt(buildSystemPrompt())
                .temperature(0.7)
                .maxTokens(2000)
                .build();

        LLMResponse response = aiService.generate(request, customerId, SCENE_PORTRAIT, organizationId);
        
        if (!response.isSuccess()) {
            throw new RuntimeException("AI 画像生成失败: " + response.getErrorMessage());
        }

        // 4. 解析响应并存储
        CompanyPortrait portrait = parseAndSavePortrait(customerId, response, organizationId);
        
        return convertToResponse(portrait);
    }

    /**
     * 获取企业画像
     * 
     * @param customerId 客户ID
     * @return 画像响应，不存在返回 null
     */
    public PortraitResponse getPortrait(String customerId) {
        CompanyPortrait portrait = extCompanyPortraitMapper.selectByCustomerId(customerId);
        if (portrait == null) {
            return null;
        }
        return convertToResponse(portrait);
    }

    /**
     * 构建 AI Prompt
     * 
     * Property 17: AI调用参数完整性
     * For any 画像生成请求，发送给 AI 服务的 Prompt 应该包含企业的基本信息（名称、行业、规模等）
     * 
     * @param profile 企业档案
     * @return Prompt 字符串
     */
    public String buildPrompt(EnterpriseProfile profile) {
        StringBuilder sb = new StringBuilder();
        sb.append("请根据以下企业信息生成企业画像分析：\n\n");
        sb.append("【企业基本信息】\n");
        sb.append("企业名称: ").append(nvl(profile.getCompanyName())).append("\n");
        sb.append("统一社会信用代码: ").append(nvl(profile.getCreditCode())).append("\n");
        sb.append("法定代表人: ").append(nvl(profile.getLegalPerson())).append("\n");
        sb.append("注册资本: ").append(formatRegCapital(profile.getRegCapital())).append("\n");
        sb.append("成立日期: ").append(formatRegDate(profile.getRegDate())).append("\n");
        sb.append("所属行业: ").append(nvl(profile.getIndustryName())).append("\n");
        sb.append("员工规模: ").append(nvl(profile.getStaffSize())).append("\n");
        sb.append("注册地址: ").append(nvl(profile.getAddress())).append("\n");
        sb.append("经营状态: ").append(nvl(profile.getStatus())).append("\n");
        
        // 添加股东和高管信息（如果有）
        if (StringUtils.isNotBlank(profile.getShareholders())) {
            sb.append("主要股东: ").append(profile.getShareholders()).append("\n");
        }
        if (StringUtils.isNotBlank(profile.getExecutives())) {
            sb.append("主要高管: ").append(profile.getExecutives()).append("\n");
        }
        
        return sb.toString();
    }

    /**
     * 构建系统提示词
     */
    private String buildSystemPrompt() {
        return """
            你是一位专业的企业分析师。请根据提供的企业信息，生成结构化的企业画像分析。
            
            你的回复必须是一个有效的 JSON 对象，包含以下四个字段：
            
            1. basics: 基本信息分析对象，包含：
               - industry: 行业定位和市场地位分析
               - scale: 企业规模评估
               - mainProducts: 主营业务/产品推断
            
            2. opportunities: 商机洞察数组，每个元素包含：
               - title: 商机标题
               - confidence: 置信度(0-1的小数)
               - source: 判断依据
            
            3. risks: 风险提示数组，每个元素包含：
               - level: 风险等级(高/中/低)
               - text: 风险描述
            
            4. sentiments: 舆情分析数组，每个元素包含：
               - title: 舆情标题
               - source: 信息来源
               - sentiment: 情感倾向(正面/中性/负面)
            
            请确保：
            - 只返回 JSON 对象，不要包含任何其他文字
            - 所有分析基于提供的企业信息
            - 使用中文回复
            """;
    }

    /**
     * 解析 AI 响应并保存画像
     * 
     * Property 16: 画像数据分类正确性
     * For any 企业画像数据，应该能够正确分类到基本信息、商机洞察、风险提示、相关舆情四个类别中
     */
    @Transactional(rollbackFor = Exception.class)
    protected CompanyPortrait parseAndSavePortrait(String customerId, LLMResponse response, String organizationId) {
        String content = response.getContent();
        
        // 解析 JSON 响应
        Map<String, Object> parsed = parseAIResponse(content);
        
        // 删除旧画像
        extCompanyPortraitMapper.deleteByCustomerId(customerId);
        
        // 创建新画像
        CompanyPortrait portrait = new CompanyPortrait();
        portrait.setId(IDGenerator.nextStr());
        portrait.setCustomerId(customerId);
        portrait.setPortrait(extractJsonField(parsed, "basics"));
        portrait.setOpportunities(extractJsonField(parsed, "opportunities"));
        portrait.setRisks(extractJsonField(parsed, "risks"));
        portrait.setPublicOpinion(extractJsonField(parsed, "sentiments"));
        portrait.setModel(response.getModel());
        portrait.setVersion(DEFAULT_VERSION);
        portrait.setSource(SOURCE_AI);
        portrait.setGeneratedAt(System.currentTimeMillis());
        portrait.setOrganizationId(organizationId);
        portrait.setCreateTime(System.currentTimeMillis());
        portrait.setUpdateTime(System.currentTimeMillis());
        portrait.setCreateUser(SessionUtils.getUserId());
        portrait.setUpdateUser(SessionUtils.getUserId());
        
        companyPortraitMapper.insert(portrait);
        
        log.info("Portrait generated and saved for customer {}", customerId);
        return portrait;
    }

    /**
     * 解析 AI 响应 JSON
     */
    @SuppressWarnings("unchecked")
    protected Map<String, Object> parseAIResponse(String content) {
        if (StringUtils.isBlank(content)) {
            return Collections.emptyMap();
        }
        
        try {
            // 尝试提取 JSON 内容（处理可能的 markdown 代码块）
            String jsonContent = extractJsonContent(content);
            return JSON.parseObject(jsonContent, Map.class);
        } catch (Exception e) {
            log.warn("Failed to parse AI response as JSON: {}", e.getMessage());
            return Collections.emptyMap();
        }
    }

    /**
     * 从响应中提取 JSON 内容
     */
    private String extractJsonContent(String content) {
        // 处理 markdown 代码块
        if (content.contains("```json")) {
            int start = content.indexOf("```json") + 7;
            int end = content.indexOf("```", start);
            if (end > start) {
                return content.substring(start, end).trim();
            }
        }
        if (content.contains("```")) {
            int start = content.indexOf("```") + 3;
            int end = content.indexOf("```", start);
            if (end > start) {
                return content.substring(start, end).trim();
            }
        }
        return content.trim();
    }

    /**
     * 提取 JSON 字段并转为字符串
     */
    private String extractJsonField(Map<String, Object> parsed, String field) {
        Object value = parsed.get(field);
        if (value == null) {
            return null;
        }
        if (value instanceof String) {
            return (String) value;
        }
        return JSON.toJSONString(value);
    }

    /**
     * 转换为响应 DTO
     */
    private PortraitResponse convertToResponse(CompanyPortrait portrait) {
        return PortraitResponse.builder()
                .customerId(portrait.getCustomerId())
                .portrait(buildPortraitDto(portrait))
                .generatedAt(portrait.getGeneratedAt())
                .model(portrait.getModel())
                .version(portrait.getVersion())
                .build();
    }

    /**
     * 构建画像 DTO
     */
    @SuppressWarnings("unchecked")
    private Portrait buildPortraitDto(CompanyPortrait portrait) {
        return Portrait.builder()
                .basics(parseBasics(portrait.getPortrait()))
                .opportunities(parseOpportunities(portrait.getOpportunities()))
                .risks(parseRisks(portrait.getRisks()))
                .sentiments(parseSentiments(portrait.getPublicOpinion()))
                .build();
    }

    private Basics parseBasics(String json) {
        if (StringUtils.isBlank(json)) {
            return null;
        }
        try {
            Map<String, Object> map = JSON.parseObject(json, Map.class);
            return Basics.builder()
                    .industry((String) map.get("industry"))
                    .scale((String) map.get("scale"))
                    .mainProducts((String) map.get("mainProducts"))
                    .build();
        } catch (Exception e) {
            return null;
        }
    }

    @SuppressWarnings("unchecked")
    private List<Opportunity> parseOpportunities(String json) {
        if (StringUtils.isBlank(json)) {
            return Collections.emptyList();
        }
        try {
            List<?> rawList = JSON.parseArray(json);
            List<Opportunity> result = new ArrayList<>();
            for (Object item : rawList) {
                if (item instanceof Map) {
                    Map<String, Object> m = (Map<String, Object>) item;
                    result.add(Opportunity.builder()
                            .title((String) m.get("title"))
                            .confidence(parseDouble(m.get("confidence")))
                            .source((String) m.get("source"))
                            .build());
                }
            }
            return result;
        } catch (Exception e) {
            return Collections.emptyList();
        }
    }

    @SuppressWarnings("unchecked")
    private List<Risk> parseRisks(String json) {
        if (StringUtils.isBlank(json)) {
            return Collections.emptyList();
        }
        try {
            List<?> rawList = JSON.parseArray(json);
            List<Risk> result = new ArrayList<>();
            for (Object item : rawList) {
                if (item instanceof Map) {
                    Map<String, Object> m = (Map<String, Object>) item;
                    result.add(Risk.builder()
                            .level((String) m.get("level"))
                            .text((String) m.get("text"))
                            .build());
                }
            }
            return result;
        } catch (Exception e) {
            return Collections.emptyList();
        }
    }

    @SuppressWarnings("unchecked")
    private List<Sentiment> parseSentiments(String json) {
        if (StringUtils.isBlank(json)) {
            return Collections.emptyList();
        }
        try {
            List<?> rawList = JSON.parseArray(json);
            List<Sentiment> result = new ArrayList<>();
            for (Object item : rawList) {
                if (item instanceof Map) {
                    Map<String, Object> m = (Map<String, Object>) item;
                    result.add(Sentiment.builder()
                            .title((String) m.get("title"))
                            .source((String) m.get("source"))
                            .sentiment((String) m.get("sentiment"))
                            .build());
                }
            }
            return result;
        } catch (Exception e) {
            return Collections.emptyList();
        }
    }

    private Double parseDouble(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Number) {
            return ((Number) value).doubleValue();
        }
        try {
            return Double.parseDouble(value.toString());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private String nvl(Object obj) {
        return obj != null ? obj.toString() : "未知";
    }

    private String formatRegCapital(java.math.BigDecimal capital) {
        if (capital == null) {
            return "未知";
        }
        return capital.toString() + " 万元";
    }

    private String formatRegDate(Long timestamp) {
        if (timestamp == null) {
            return "未知";
        }
        try {
            LocalDate localDate = Instant.ofEpochMilli(timestamp)
                    .atZone(ZoneId.systemDefault())
                    .toLocalDate();
            return localDate.format(DateTimeFormatter.ofPattern("yyyy-MM-dd"));
        } catch (Exception e) {
            return "格式错误";
        }
    }
}
