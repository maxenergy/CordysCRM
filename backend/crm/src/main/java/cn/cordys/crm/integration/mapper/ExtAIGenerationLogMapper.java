package cn.cordys.crm.integration.mapper;

import cn.cordys.crm.integration.domain.AIGenerationLog;
import org.apache.ibatis.annotations.Param;

import java.util.List;

/**
 * AI生成日志扩展Mapper
 *
 * @author cordys
 * @date 2025-12-10
 */
public interface ExtAIGenerationLogMapper {

    /**
     * 插入日志
     *
     * @param log 日志
     * @return 插入行数
     */
    int insert(@Param("log") AIGenerationLog log);

    /**
     * 根据客户ID和场景查询日志
     *
     * @param customerId 客户ID
     * @param scene      场景
     * @param limit      限制数量
     * @return 日志列表
     */
    List<AIGenerationLog> selectByCustomerAndScene(
            @Param("customerId") String customerId,
            @Param("scene") String scene,
            @Param("limit") int limit);

    /**
     * 统计Token消耗
     *
     * @param organizationId 组织ID
     * @param startTime      开始时间
     * @param endTime        结束时间
     * @return Token总数
     */
    Long sumTokensByOrganization(
            @Param("orgId") String organizationId,
            @Param("startTime") Long startTime,
            @Param("endTime") Long endTime);
}
