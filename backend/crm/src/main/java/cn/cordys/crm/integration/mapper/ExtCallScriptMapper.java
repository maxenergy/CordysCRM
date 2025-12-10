package cn.cordys.crm.integration.mapper;

import cn.cordys.crm.integration.domain.CallScript;
import org.apache.ibatis.annotations.Param;

import java.util.List;

/**
 * 话术记录扩展Mapper
 *
 * @author cordys
 * @date 2025-12-10
 */
public interface ExtCallScriptMapper {

    /**
     * 根据客户ID查询话术历史
     *
     * @param customerId 客户ID
     * @param limit      限制数量
     * @return 话术列表
     */
    List<CallScript> selectByCustomerId(@Param("customerId") String customerId, @Param("limit") int limit);

    /**
     * 根据客户ID和场景查询话术
     *
     * @param customerId 客户ID
     * @param scene      场景
     * @param limit      限制数量
     * @return 话术列表
     */
    List<CallScript> selectByCustomerAndScene(
            @Param("customerId") String customerId,
            @Param("scene") String scene,
            @Param("limit") int limit);
}
