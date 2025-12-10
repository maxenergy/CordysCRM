package cn.cordys.crm.integration.mapper;

import cn.cordys.crm.integration.domain.IntegrationConfig;
import org.apache.ibatis.annotations.Param;

import java.util.List;

/**
 * 集成配置扩展Mapper
 *
 * @author cordys
 * @date 2025-12-10
 */
public interface ExtIntegrationConfigMapper {

    /**
     * 根据配置键查询
     *
     * @param configKey      配置键
     * @param organizationId 组织ID
     * @return 配置
     */
    IntegrationConfig selectByKey(@Param("configKey") String configKey, @Param("orgId") String organizationId);

    /**
     * 查询组织的所有配置
     *
     * @param organizationId 组织ID
     * @return 配置列表
     */
    List<IntegrationConfig> selectByOrganization(@Param("orgId") String organizationId);

    /**
     * 更新或插入配置
     *
     * @param config 配置
     * @return 影响行数
     */
    int upsert(@Param("config") IntegrationConfig config);
}
