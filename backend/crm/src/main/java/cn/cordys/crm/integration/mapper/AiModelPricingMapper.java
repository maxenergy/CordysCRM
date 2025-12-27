package cn.cordys.crm.integration.mapper;

import cn.cordys.crm.integration.domain.AiModelPricing;
import org.apache.ibatis.annotations.Param;

import java.util.List;

/**
 * AI模型定价配置Mapper
 * 
 * Requirements: 8.1, 8.2, 8.3, 8.4
 * 
 * @author cordys
 * @date 2025-12-27
 */
public interface AiModelPricingMapper {
    
    /**
     * 查询所有启用的定价配置
     * 
     * @return 定价配置列表
     */
    List<AiModelPricing> selectAllActive();
    
    /**
     * 根据提供商和模型查询定价配置
     * 
     * @param providerCode 提供商代码
     * @param modelCode 模型代码
     * @return 定价配置
     */
    AiModelPricing selectByProviderAndModel(@Param("providerCode") String providerCode, 
                                            @Param("modelCode") String modelCode);
    
    /**
     * 插入定价配置
     * 
     * @param pricing 定价配置
     * @return 影响行数
     */
    int insert(AiModelPricing pricing);
    
    /**
     * 更新定价配置
     * 
     * @param pricing 定价配置
     * @return 影响行数
     */
    int update(AiModelPricing pricing);
    
    /**
     * 根据ID删除定价配置
     * 
     * @param id 主键ID
     * @return 影响行数
     */
    int deleteById(@Param("id") String id);
}
