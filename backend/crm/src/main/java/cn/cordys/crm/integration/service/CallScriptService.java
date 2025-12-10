package cn.cordys.crm.integration.service;

import cn.cordys.common.uid.IDGenerator;
import cn.cordys.common.util.JSON;
import cn.cordys.security.SessionUtils;
import cn.cordys.crm.integration.ai.LLMRequest;
import cn.cordys.crm.integration.ai.LLMResponse;
import cn.cordys.crm.integration.domain.CallScript;
import cn.cordys.crm.integration.domain.CallScriptTemplate;
import cn.cordys.crm.integration.domain.CompanyPortrait;
import cn.cordys.crm.integration.domain.EnterpriseProfile;
import cn.cordys.crm.integration.dto.request.ScriptGenerateRequest;
import cn.cordys.crm.integration.dto.response.ScriptResponse;
import cn.cordys.crm.integration.mapper.ExtCallScriptMapper;
import cn.cordys.crm.integration.mapper.ExtCompanyPortraitMapper;
import cn.cordys.mybatis.BaseMapper;
import jakarta.annotation.Resource;
import org.apache.commons.lang3.StringUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;

/**
 * 话术生成服务
 * 基于模板和画像生成 AI 话术
 * 
 * Requirements: 6.5, 6.6, 6.7, 6.8, 6.10
 * 
 * @author cordys
 * @date 2025-12-10
 */
@Service
public class CallScriptService {

    private static final Logger log = LoggerFactory.getLogger(CallScriptService.class);

    private static final String SCENE_SCRIPT = "script";

    @Resource
    private AIService aiService;

    @Resource
    private EnterpriseService enterpriseService;

    @Resource
    private CallScriptTemplateService templateService;

    @Resource
    private BaseMapper<CallScript> callScriptMapper;

    @Resource
    private ExtCallScriptMapper extCallScriptMapper;

    @Resource
    private ExtCompanyPortraitMapper extCompanyPortraitMapper;

    /**
     * 生成话术
     * 
     * Property 20: 话术生成参数传递
     * For any 话术生成请求，发送给 AI 服务的请求应该包含用户选择的场景、渠道、语气参数
     * 
     * @param request 生成请求
     * @param organizationId 组织ID
     * @return 话术响应
     */
    @Transactional(rollbackFor = Exception.class)
    public ScriptResponse generateScript(ScriptGenerateRequest request, String organizationId) {
        // 1. 获取企业档案
        EnterpriseProfile profile = enterpriseService.findByCustomerId(request.getCustomerId());
        if (profile == null) {
            throw new IllegalArgumentException("企业档案不存在: customerId=" + request.getCustomerId());
        }

        // 2. 获取企业画像（如果有）
        CompanyPortrait portrait = extCompanyPortraitMapper.selectByCustomerId(request.getCustomerId());

        // 3. 获取模板（如果指定）
        CallScriptTemplate template = null;
        if (StringUtils.isNotBlank(request.getTemplateId())) {
            template = templateService.getById(request.getTemplateId());
        }

        // 4. 构建 Prompt
        String prompt = buildPrompt(request, profile, portrait, template);
        
        LLMRequest llmRequest = LLMRequest.builder()
                .prompt(prompt)
                .systemPrompt(buildSystemPrompt(request))
                .temperature(0.8)
                .maxTokens(1500)
                .build();

        // 5. 调用 AI 生成
        LLMResponse response = aiService.generate(llmRequest, request.getCustomerId(), SCENE_SCRIPT, organizationId);
        
        if (!response.isSuccess()) {
            throw new RuntimeException("AI 话术生成失败: " + response.getErrorMessage());
        }

        // 6. 保存话术记录
        CallScript script = saveScript(request, response, organizationId);

        return convertToResponse(script);
    }

    /**
     * 获取话术历史
     * 
     * Property 23: 话术历史记录完整性
     * For any 用户在同一会话中生成的多次话术，应该全部保留在历史记录中，且顺序与生成顺序一致
     * 
     * @param customerId 客户ID
     * @param limit 限制数量
     * @return 话术历史列表
     */
    public List<ScriptResponse> getScriptHistory(String customerId, int limit) {
        List<CallScript> scripts = extCallScriptMapper.selectByCustomerId(customerId, limit);
        return scripts.stream()
                .map(this::convertToResponse)
                .toList();
    }

    /**
     * 根据ID获取话术
     * 
     * @param scriptId 话术ID
     * @return 话术响应
     */
    public ScriptResponse getById(String scriptId) {
        CallScript script = callScriptMapper.selectByPrimaryKey(scriptId);
        if (script == null) {
            return null;
        }
        return convertToResponse(script);
    }

    /**
     * 更新话术内容（用户编辑）
     * 
     * Property 22: 话术保存往返一致性
     * For any 用户编辑并保存的话术，保存后查询应该得到完全相同的内容
     * 
     * @param scriptId 话术ID
     * @param content 新内容
     * @return 更新后的话术
     */
    @Transactional(rollbackFor = Exception.class)
    public ScriptResponse updateContent(String scriptId, String content) {
        CallScript script = callScriptMapper.selectByPrimaryKey(scriptId);
        if (script == null) {
            throw new IllegalArgumentException("话术不存在: scriptId=" + scriptId);
        }
        
        script.setContent(content);
        script.setUpdateTime(System.currentTimeMillis());
        script.setUpdateUser(SessionUtils.getUserId());
        
        callScriptMapper.update(script);
        
        return convertToResponse(script);
    }

    /**
     * 构建话术生成 Prompt
     */
    private String buildPrompt(ScriptGenerateRequest request, EnterpriseProfile profile, 
                               CompanyPortrait portrait, CallScriptTemplate template) {
        StringBuilder sb = new StringBuilder();
        
        sb.append("请为以下客户生成").append(getSceneLabel(request.getScene())).append("话术：\n\n");
        
        // 企业基本信息
        sb.append("【客户信息】\n");
        sb.append("企业名称: ").append(nvl(profile.getCompanyName())).append("\n");
        sb.append("所属行业: ").append(nvl(profile.getIndustryName())).append("\n");
        sb.append("企业规模: ").append(nvl(profile.getStaffSize())).append("\n");
        
        // 画像信息（如果有）
        if (portrait != null && StringUtils.isNotBlank(portrait.getPortrait())) {
            sb.append("\n【企业画像】\n");
            sb.append(portrait.getPortrait()).append("\n");
            
            if (StringUtils.isNotBlank(portrait.getOpportunities())) {
                sb.append("商机洞察: ").append(portrait.getOpportunities()).append("\n");
            }
        }
        
        // 生成参数
        sb.append("\n【生成要求】\n");
        sb.append("场景: ").append(getSceneLabel(request.getScene())).append("\n");
        sb.append("渠道: ").append(getChannelLabel(request.getChannel())).append("\n");
        sb.append("语气: ").append(getToneLabel(request.getTone())).append("\n");
        
        // 模板参考（如果有）
        if (template != null && StringUtils.isNotBlank(template.getContent())) {
            sb.append("\n【参考模板】\n");
            sb.append(template.getContent()).append("\n");
        }
        
        return sb.toString();
    }

    /**
     * 构建系统提示词
     */
    private String buildSystemPrompt(ScriptGenerateRequest request) {
        return String.format("""
            你是一位专业的销售话术专家。请根据提供的客户信息和要求，生成一段%s话术。
            
            要求：
            1. 话术应该自然流畅，符合%s的沟通风格
            2. 语气应该%s
            3. 内容应该针对客户的行业特点和潜在需求
            4. 直接输出话术内容，不要包含任何解释或标题
            5. 使用中文
            """, 
            getSceneLabel(request.getScene()),
            getChannelLabel(request.getChannel()),
            getToneLabel(request.getTone()));
    }

    /**
     * 保存话术记录
     */
    private CallScript saveScript(ScriptGenerateRequest request, LLMResponse response, String organizationId) {
        CallScript script = new CallScript();
        script.setId(IDGenerator.nextStr());
        script.setCustomerId(request.getCustomerId());
        script.setOpportunityId(request.getOpportunityId());
        script.setTemplateId(request.getTemplateId());
        script.setScene(request.getScene());
        script.setChannel(request.getChannel());
        script.setTone(request.getTone());
        script.setLanguage("zh-CN");
        script.setContent(response.getContent());
        script.setModel(response.getModel());
        script.setGeneratedAt(System.currentTimeMillis());
        script.setOrganizationId(organizationId);
        script.setCreateTime(System.currentTimeMillis());
        script.setUpdateTime(System.currentTimeMillis());
        script.setCreateUser(SessionUtils.getUserId());
        script.setUpdateUser(SessionUtils.getUserId());
        
        callScriptMapper.insert(script);
        
        log.info("Script generated and saved: scriptId={}, customerId={}", script.getId(), request.getCustomerId());
        return script;
    }

    private ScriptResponse convertToResponse(CallScript script) {
        return ScriptResponse.builder()
                .scriptId(script.getId())
                .customerId(script.getCustomerId())
                .content(script.getContent())
                .scene(script.getScene())
                .channel(script.getChannel())
                .tone(script.getTone())
                .model(script.getModel())
                .generatedAt(script.getGeneratedAt())
                .build();
    }

    private String getSceneLabel(String scene) {
        return switch (scene) {
            case "outreach" -> "首次触达";
            case "followup" -> "跟进回访";
            case "renewal" -> "续费挽留";
            case "meeting" -> "约见面谈";
            default -> scene;
        };
    }

    private String getChannelLabel(String channel) {
        return switch (channel) {
            case "phone" -> "电话沟通";
            case "wechat" -> "微信沟通";
            case "email" -> "邮件沟通";
            default -> channel;
        };
    }

    private String getToneLabel(String tone) {
        return switch (tone) {
            case "professional" -> "专业正式";
            case "enthusiastic" -> "热情友好";
            case "concise" -> "简洁明了";
            default -> tone;
        };
    }

    private String nvl(Object obj) {
        return obj != null ? obj.toString() : "未知";
    }
}
