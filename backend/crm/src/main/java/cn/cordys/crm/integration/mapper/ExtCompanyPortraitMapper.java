package cn.cordys.crm.integration.mapper;

import cn.cordys.crm.integration.domain.CompanyPortrait;
import org.apache.ibatis.annotations.Param;

/**
 * AI企业画像扩展Mapper
 *
 * @author cordys
 * @date 2025-12-10
 */
public interface ExtCompanyPortraitMapper {

    /**
     * 根据客户ID查询画像
     *
     * @param customerId 客户ID
     * @return 企业画像
     */
    CompanyPortrait selectByCustomerId(@Param("customerId") String customerId);

    /**
     * 根据客户ID删除画像
     *
     * @param customerId 客户ID
     * @return 删除行数
     */
    int deleteByCustomerId(@Param("customerId") String customerId);
}
