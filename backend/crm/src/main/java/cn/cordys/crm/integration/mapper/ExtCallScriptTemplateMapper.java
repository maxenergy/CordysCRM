package cn.cordys.crm.integration.mapper;

import cn.cordys.crm.integration.domain.CallScriptTemplate;
import org.apache.ibatis.annotations.Param;

import java.util.List;

/**
 * 话术模板扩展Mapper
 *
 * @author cordys
 * @date 2025-12-10
 */
public interface ExtCallScriptTemplateMapper {

    /**
     * 查询启用的模板列表
     *
     * @param industry       行业
     * @param scene          场景
     * @param channel        渠道
     * @param organizationId 组织ID
     * @return 模板列表
     */
    List<CallScriptTemplate> selectEnabledTemplates(
            @Param("industry") String industry,
            @Param("scene") String scene,
            @Param("channel") String channel,
            @Param("orgId") String organizationId);

    /**
     * 按行业和场景分组查询模板
     *
     * @param organizationId 组织ID
     * @return 模板列表
     */
    List<CallScriptTemplate> selectGroupedTemplates(@Param("orgId") String organizationId);
}
