package cn.cordys.crm.integration.mapper;

import cn.cordys.crm.integration.domain.EnterpriseProfile;
import org.apache.ibatis.annotations.Param;

import java.util.List;

/**
 * 企业工商信息扩展Mapper
 *
 * @author cordys
 * @date 2025-12-10
 */
public interface ExtEnterpriseProfileMapper {

    /**
     * 根据统一社会信用代码查询
     *
     * @param creditCode     统一社会信用代码
     * @param organizationId 组织ID
     * @return 企业工商信息
     */
    EnterpriseProfile selectByCreditCode(@Param("creditCode") String creditCode, @Param("orgId") String organizationId);

    /**
     * 根据客户ID查询
     *
     * @param customerId 客户ID
     * @return 企业工商信息
     */
    EnterpriseProfile selectByCustomerId(@Param("customerId") String customerId);

    /**
     * 根据企业名称模糊查询
     *
     * @param companyName    企业名称
     * @param organizationId 组织ID
     * @return 企业工商信息列表
     */
    List<EnterpriseProfile> searchByCompanyName(@Param("companyName") String companyName, @Param("orgId") String organizationId);
}
