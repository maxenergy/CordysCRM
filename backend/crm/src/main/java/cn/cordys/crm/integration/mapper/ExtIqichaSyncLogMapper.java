package cn.cordys.crm.integration.mapper;

import cn.cordys.crm.integration.domain.IqichaSyncLog;
import org.apache.ibatis.annotations.Param;

import java.util.List;

/**
 * 爱企查同步日志扩展Mapper
 *
 * @author cordys
 * @date 2025-12-10
 */
public interface ExtIqichaSyncLogMapper {

    /**
     * 插入日志
     *
     * @param log 日志
     * @return 插入行数
     */
    int insert(@Param("log") IqichaSyncLog log);

    /**
     * 根据客户ID查询日志
     *
     * @param customerId 客户ID
     * @param limit      限制数量
     * @return 日志列表
     */
    List<IqichaSyncLog> selectByCustomerId(@Param("customerId") String customerId, @Param("limit") int limit);

    /**
     * 根据操作类型查询日志
     *
     * @param action         操作类型
     * @param organizationId 组织ID
     * @param startTime      开始时间
     * @param endTime        结束时间
     * @return 日志列表
     */
    List<IqichaSyncLog> selectByAction(
            @Param("action") String action,
            @Param("orgId") String organizationId,
            @Param("startTime") Long startTime,
            @Param("endTime") Long endTime);
}
