package cn.cordys.crm.integration.service;

import cn.cordys.common.uid.IDGenerator;
import cn.cordys.security.SessionUtils;
import cn.cordys.context.OrganizationContext;
import cn.cordys.crm.integration.domain.IqichaSyncLog;
import cn.cordys.crm.integration.mapper.ExtIqichaSyncLogMapper;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.annotation.Resource;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

/**
 * 爱企查同步日志服务
 * 记录所有爱企查相关的同步操作
 * 
 * Requirements: 9.2
 * 
 * @author cordys
 * @date 2025-12-10
 */
@Service
public class IqichaSyncLogService {

    /**
     * 操作类型常量
     */
    public static final String ACTION_IMPORT = "import";
    public static final String ACTION_SYNC = "sync";
    public static final String ACTION_UPDATE = "update";
    public static final String ACTION_SEARCH = "search";

    @Resource
    private ExtIqichaSyncLogMapper syncLogMapper;

    private final ObjectMapper objectMapper = new ObjectMapper();

    /**
     * 记录导入操作日志
     * 
     * Property 28: 操作日志完整性
     * For any 爱企查服务调用，应该记录包含操作人、目标企业、操作类型、时间的日志
     * 
     * @param customerId 客户ID
     * @param iqichaId 爱企查企业ID
     * @param requestParams 请求参数
     * @param responseCode 响应码
     * @param responseMsg 响应消息
     * @param diffSnapshot 数据变更快照
     * @return 日志记录
     */
    public IqichaSyncLog logImport(String customerId, String iqichaId, 
                                   Map<String, Object> requestParams,
                                   int responseCode, String responseMsg,
                                   Map<String, Object> diffSnapshot) {
        return createLog(ACTION_IMPORT, customerId, iqichaId, 
                        requestParams, responseCode, responseMsg, diffSnapshot, null);
    }

    /**
     * 记录同步操作日志
     * 
     * @param customerId 客户ID
     * @param iqichaId 爱企查企业ID
     * @param responseCode 响应码
     * @param responseMsg 响应消息
     * @return 日志记录
     */
    public IqichaSyncLog logSync(String customerId, String iqichaId,
                                 int responseCode, String responseMsg) {
        return createLog(ACTION_SYNC, customerId, iqichaId, 
                        null, responseCode, responseMsg, null, null);
    }

    /**
     * 记录更新操作日志
     * 
     * @param customerId 客户ID
     * @param iqichaId 爱企查企业ID
     * @param diffSnapshot 数据变更快照
     * @param responseCode 响应码
     * @param responseMsg 响应消息
     * @return 日志记录
     */
    public IqichaSyncLog logUpdate(String customerId, String iqichaId,
                                   Map<String, Object> diffSnapshot,
                                   int responseCode, String responseMsg) {
        return createLog(ACTION_UPDATE, customerId, iqichaId, 
                        null, responseCode, responseMsg, diffSnapshot, null);
    }

    /**
     * 记录搜索操作日志
     * 
     * @param searchKeyword 搜索关键词
     * @param responseCode 响应码
     * @param responseMsg 响应消息
     * @param cost 费用
     * @return 日志记录
     */
    public IqichaSyncLog logSearch(String searchKeyword, int responseCode, 
                                   String responseMsg, BigDecimal cost) {
        Map<String, Object> params = Map.of("keyword", searchKeyword);
        return createLog(ACTION_SEARCH, null, null, 
                        params, responseCode, responseMsg, null, cost);
    }

    /**
     * 创建并保存日志记录
     * 
     * @param action 操作类型
     * @param customerId 客户ID
     * @param iqichaId 爱企查企业ID
     * @param requestParams 请求参数
     * @param responseCode 响应码
     * @param responseMsg 响应消息
     * @param diffSnapshot 数据变更快照
     * @param cost 费用
     * @return 日志记录
     */
    public IqichaSyncLog createLog(String action, String customerId, String iqichaId,
                                   Map<String, Object> requestParams,
                                   int responseCode, String responseMsg,
                                   Map<String, Object> diffSnapshot, BigDecimal cost) {
        IqichaSyncLog log = new IqichaSyncLog();
        log.setId(IDGenerator.nextStr());
        log.setOperatorId(SessionUtils.getUserId());
        log.setCustomerId(customerId);
        log.setIqichaId(iqichaId);
        log.setAction(action);
        log.setRequestParams(toJson(requestParams));
        log.setResponseCode(responseCode);
        log.setResponseMsg(responseMsg);
        log.setDiffSnapshot(toJson(diffSnapshot));
        log.setCost(cost);
        log.setOrganizationId(OrganizationContext.getOrganizationId());
        log.setCreateTime(System.currentTimeMillis());

        syncLogMapper.insert(log);
        return log;
    }

    /**
     * 验证日志记录是否完整
     * 
     * Property 28: 操作日志完整性
     * 
     * @param log 日志记录
     * @return 是否完整
     */
    public boolean isLogComplete(IqichaSyncLog log) {
        if (log == null) {
            return false;
        }
        // 必须包含：操作人、操作类型、时间
        return log.getOperatorId() != null 
                && log.getAction() != null 
                && log.getCreateTime() != null;
    }

    /**
     * 根据客户ID查询日志
     * 
     * @param customerId 客户ID
     * @param limit 限制数量
     * @return 日志列表
     */
    public List<IqichaSyncLog> getLogsByCustomerId(String customerId, int limit) {
        return syncLogMapper.selectByCustomerId(customerId, limit);
    }

    /**
     * 根据操作类型查询日志
     * 
     * @param action 操作类型
     * @param organizationId 组织ID
     * @param startTime 开始时间
     * @param endTime 结束时间
     * @return 日志列表
     */
    public List<IqichaSyncLog> getLogsByAction(String action, String organizationId,
                                               Long startTime, Long endTime) {
        return syncLogMapper.selectByAction(action, organizationId, startTime, endTime);
    }

    /**
     * 将对象转换为JSON字符串
     */
    private String toJson(Object obj) {
        if (obj == null) {
            return null;
        }
        try {
            return objectMapper.writeValueAsString(obj);
        } catch (JsonProcessingException e) {
            return obj.toString();
        }
    }
}
