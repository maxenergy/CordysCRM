package cn.cordys.crm.integration.service;

import cn.cordys.crm.integration.domain.AIGenerationLog;
import cn.cordys.crm.integration.mapper.ExtAIGenerationLogMapper;
import jakarta.annotation.Resource;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * AI 生成日志服务
 * 记录 AI 调用的详细信息
 * 
 * Requirements: 5.8, 9.3
 * 
 * @author cordys
 * @date 2025-12-10
 */
@Service
public class AIGenerationLogService {

    private static final Logger log = LoggerFactory.getLogger(AIGenerationLogService.class);

    @Resource
    private ExtAIGenerationLogMapper aiGenerationLogMapper;

    /**
     * 查询客户的 AI 调用日志
     * 
     * Property 19: AI调用日志完整性
     * For any AI 服务调用，应该记录包含模型名称、Token消耗、耗时、状态的日志记录
     * 
     * @param customerId 客户ID
     * @param scene 场景
     * @param limit 限制数量
     * @return 日志列表
     */
    public List<AIGenerationLog> getLogsByCustomer(String customerId, String scene, int limit) {
        return aiGenerationLogMapper.selectByCustomerAndScene(customerId, scene, limit);
    }

    /**
     * 统计组织的 Token 消耗
     * 
     * @param organizationId 组织ID
     * @param startTime 开始时间
     * @param endTime 结束时间
     * @return Token 总数
     */
    public Long sumTokensByOrganization(String organizationId, Long startTime, Long endTime) {
        return aiGenerationLogMapper.sumTokensByOrganization(organizationId, startTime, endTime);
    }

    /**
     * 验证日志完整性
     * 
     * Property 19: AI调用日志完整性
     * 
     * @param logEntry 日志记录
     * @return 是否完整
     */
    public boolean validateLogCompleteness(AIGenerationLog logEntry) {
        if (logEntry == null) {
            return false;
        }
        
        // 必须包含模型名称
        if (logEntry.getModel() == null || logEntry.getModel().isBlank()) {
            return false;
        }
        
        // 必须包含状态
        if (logEntry.getStatus() == null || logEntry.getStatus().isBlank()) {
            return false;
        }
        
        // 必须包含耗时
        if (logEntry.getLatencyMs() == null) {
            return false;
        }
        
        // 成功的调用必须包含 Token 消耗
        if ("success".equals(logEntry.getStatus())) {
            if (logEntry.getTokensPrompt() == null && logEntry.getTokensCompletion() == null) {
                return false;
            }
        }
        
        return true;
    }
}
