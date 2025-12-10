package cn.cordys.crm.integration.service;

import cn.cordys.common.uid.IDGenerator;
import cn.cordys.security.SessionUtils;
import cn.cordys.crm.integration.domain.CallScriptTemplate;
import cn.cordys.crm.integration.mapper.ExtCallScriptTemplateMapper;
import cn.cordys.mybatis.BaseMapper;
import jakarta.annotation.Resource;
import org.apache.commons.lang3.StringUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * 话术模板服务
 * 管理话术模板的 CRUD 和变量解析
 * 
 * Requirements: 7.1, 7.2, 7.3, 7.4, 7.5
 * 
 * @author cordys
 * @date 2025-12-10
 */
@Service
public class CallScriptTemplateService {

    private static final Logger log = LoggerFactory.getLogger(CallScriptTemplateService.class);

    /**
     * 变量占位符正则表达式: {{变量名}}
     */
    private static final Pattern VARIABLE_PATTERN = Pattern.compile("\\{\\{([^}]+)\\}\\}");

    @Resource
    private BaseMapper<CallScriptTemplate> callScriptTemplateMapper;

    @Resource
    private ExtCallScriptTemplateMapper extCallScriptTemplateMapper;

    /**
     * 获取启用的模板列表
     * 
     * Property 25: 模板状态影响可用性
     * For any 被禁用的话术模板，不应该出现在话术生成时的可用模板列表中
     * 
     * @param industry 行业
     * @param scene 场景
     * @param channel 渠道
     * @param organizationId 组织ID
     * @return 启用的模板列表
     */
    public List<CallScriptTemplate> getEnabledTemplates(String industry, String scene, 
                                                         String channel, String organizationId) {
        return extCallScriptTemplateMapper.selectEnabledTemplates(industry, scene, channel, organizationId);
    }

    /**
     * 获取分组的模板列表
     * 
     * Property 24: 模板列表分类正确性
     * For any 话术模板列表查询，返回的模板应该按行业和场景正确分类
     * 
     * @param organizationId 组织ID
     * @return 按行业和场景分组的模板
     */
    public Map<String, Map<String, List<CallScriptTemplate>>> getGroupedTemplates(String organizationId) {
        List<CallScriptTemplate> templates = extCallScriptTemplateMapper.selectGroupedTemplates(organizationId);
        
        Map<String, Map<String, List<CallScriptTemplate>>> grouped = new LinkedHashMap<>();
        
        for (CallScriptTemplate template : templates) {
            String industry = StringUtils.defaultIfBlank(template.getIndustry(), "通用");
            String scene = StringUtils.defaultIfBlank(template.getScene(), "其他");
            
            grouped.computeIfAbsent(industry, k -> new LinkedHashMap<>())
                   .computeIfAbsent(scene, k -> new ArrayList<>())
                   .add(template);
        }
        
        return grouped;
    }

    /**
     * 根据ID获取模板
     * 
     * @param templateId 模板ID
     * @return 模板
     */
    public CallScriptTemplate getById(String templateId) {
        if (StringUtils.isBlank(templateId)) {
            return null;
        }
        return callScriptTemplateMapper.selectByPrimaryKey(templateId);
    }

    /**
     * 解析模板中的变量占位符
     * 
     * Property 21: 话术模板变量解析
     * For any 包含变量占位符（如 {{公司名称}}）的话术模板，应该能够正确识别并列出所有变量
     * 
     * @param content 模板内容
     * @return 变量名列表
     */
    public List<String> parseVariables(String content) {
        if (StringUtils.isBlank(content)) {
            return Collections.emptyList();
        }
        
        List<String> variables = new ArrayList<>();
        Matcher matcher = VARIABLE_PATTERN.matcher(content);
        
        while (matcher.find()) {
            String variable = matcher.group(1).trim();
            if (!variables.contains(variable)) {
                variables.add(variable);
            }
        }
        
        return variables;
    }

    /**
     * 替换模板中的变量
     * 
     * @param content 模板内容
     * @param variables 变量值映射
     * @return 替换后的内容
     */
    public String replaceVariables(String content, Map<String, String> variables) {
        if (StringUtils.isBlank(content) || variables == null || variables.isEmpty()) {
            return content;
        }
        
        String result = content;
        for (Map.Entry<String, String> entry : variables.entrySet()) {
            String placeholder = "{{" + entry.getKey() + "}}";
            String value = StringUtils.defaultString(entry.getValue(), "");
            result = result.replace(placeholder, value);
        }
        
        return result;
    }

    /**
     * 创建模板
     * 
     * @param template 模板
     * @param organizationId 组织ID
     * @return 创建的模板
     */
    @Transactional(rollbackFor = Exception.class)
    public CallScriptTemplate createTemplate(CallScriptTemplate template, String organizationId) {
        template.setId(IDGenerator.nextStr());
        template.setOrganizationId(organizationId);
        template.setEnabled(true);
        template.setVersion("v1");
        template.setCreateTime(System.currentTimeMillis());
        template.setUpdateTime(System.currentTimeMillis());
        template.setCreateUser(SessionUtils.getUserId());
        template.setUpdateUser(SessionUtils.getUserId());
        
        // 自动解析变量
        List<String> vars = parseVariables(template.getContent());
        if (!vars.isEmpty()) {
            template.setVariables(cn.cordys.common.util.JSON.toJSONString(vars));
        }
        
        callScriptTemplateMapper.insert(template);
        return template;
    }

    /**
     * 更新模板
     * 
     * @param template 模板
     * @return 更新的模板
     */
    @Transactional(rollbackFor = Exception.class)
    public CallScriptTemplate updateTemplate(CallScriptTemplate template) {
        template.setUpdateTime(System.currentTimeMillis());
        template.setUpdateUser(SessionUtils.getUserId());
        
        // 自动解析变量
        List<String> vars = parseVariables(template.getContent());
        if (!vars.isEmpty()) {
            template.setVariables(cn.cordys.common.util.JSON.toJSONString(vars));
        }
        
        callScriptTemplateMapper.update(template);
        return template;
    }

    /**
     * 启用/禁用模板
     * 
     * @param templateId 模板ID
     * @param enabled 是否启用
     */
    @Transactional(rollbackFor = Exception.class)
    public void setEnabled(String templateId, boolean enabled) {
        CallScriptTemplate template = callScriptTemplateMapper.selectByPrimaryKey(templateId);
        if (template != null) {
            template.setEnabled(enabled);
            template.setUpdateTime(System.currentTimeMillis());
            template.setUpdateUser(SessionUtils.getUserId());
            callScriptTemplateMapper.update(template);
        }
    }
}
