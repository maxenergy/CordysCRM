package cn.cordys.crm.integration.service;

import cn.cordys.context.OrganizationContext;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.Resource;
import lombok.extern.slf4j.Slf4j;
import org.apache.commons.lang3.StringUtils;
import org.springframework.http.*;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.net.HttpURLConnection;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * 爱企查搜索服务
 * 通过爱企查 API 搜索企业信息
 *
 * @author cordys
 * @date 2025-12-12
 */
@Slf4j
@Service
public class IqichaSearchService {

    private static final String IQICHA_SEARCH_URL = "https://aiqicha.baidu.com/s/advanceFilterAjax";
    private static final String IQICHA_DETAIL_URL = "https://aiqicha.baidu.com/detail/compinfo";

    @Resource
    private IntegrationConfigService configService;

    @Resource
    private ObjectMapper objectMapper;

    private RestTemplate restTemplate;

    /**
     * 初始化 RestTemplate，禁用自动重定向以便检测验证码
     */
    @PostConstruct
    public void init() {
        // 创建自定义的请求工厂，禁用自动重定向
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory() {
            @Override
            protected void prepareConnection(HttpURLConnection connection, String httpMethod) throws java.io.IOException {
                super.prepareConnection(connection, httpMethod);
                // 禁用自动重定向
                connection.setInstanceFollowRedirects(false);
            }
        };
        factory.setConnectTimeout(10000);  // 10秒连接超时
        factory.setReadTimeout(30000);      // 30秒读取超时

        this.restTemplate = new RestTemplate(factory);

        // 设置自定义错误处理器，不对 3xx/4xx 响应抛出异常
        this.restTemplate.setErrorHandler(new org.springframework.web.client.ResponseErrorHandler() {
            @Override
            public boolean hasError(org.springframework.http.client.ClientHttpResponse response) throws java.io.IOException {
                // 只对 5xx 错误抛出异常，3xx 和 4xx 由业务代码处理
                return response.getStatusCode().is5xxServerError();
            }

            @Override
            public void handleError(org.springframework.http.client.ClientHttpResponse response) throws java.io.IOException {
                log.error("爱企查服务器错误: {}", response.getStatusCode());
            }
        });

        log.info("IqichaSearchService 初始化完成，已禁用自动重定向");
    }

    /**
     * 搜索企业
     * 
     * @param keyword 搜索关键词
     * @param page 页码
     * @param pageSize 每页数量
     * @return 搜索结果
     */
    public SearchResult searchEnterprise(String keyword, int page, int pageSize) {
        String organizationId = OrganizationContext.getOrganizationId();
        Optional<String> cookieOpt = configService.getIqichaCookie(organizationId);
        
        if (cookieOpt.isEmpty() || StringUtils.isBlank(cookieOpt.get())) {
            log.warn("爱企查 Cookie 未配置");
            return SearchResult.error("请先在系统设置中配置爱企查 Cookie");
        }

        try {
            String encodedKeyword = URLEncoder.encode(keyword, StandardCharsets.UTF_8);
            String url = IQICHA_SEARCH_URL + "?q=" + encodedKeyword + "&p=" + page + "&s=" + pageSize;

            HttpHeaders headers = new HttpHeaders();
            headers.set("Cookie", cookieOpt.get());
            headers.set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36");
            headers.set("Referer", "https://aiqicha.baidu.com/s?q=" + encodedKeyword);
            headers.set("Accept", "application/json, text/plain, */*");
            headers.set("Accept-Language", "zh-CN,zh;q=0.9,en;q=0.8");
            headers.set("sec-ch-ua", "\"Not_A Brand\";v=\"8\", \"Chromium\";v=\"120\", \"Google Chrome\";v=\"120\"");
            headers.set("sec-ch-ua-mobile", "?0");
            headers.set("sec-ch-ua-platform", "\"Windows\"");
            headers.set("sec-fetch-dest", "empty");
            headers.set("sec-fetch-mode", "cors");
            headers.set("sec-fetch-site", "same-origin");

            HttpEntity<String> entity = new HttpEntity<>(headers);
            ResponseEntity<String> response = restTemplate.exchange(url, HttpMethod.GET, entity, String.class);

            if (response.getStatusCode() == HttpStatus.OK && response.getBody() != null) {
                return parseSearchResponse(response.getBody());
            } else if (response.getStatusCode().is3xxRedirection()) {
                String location = response.getHeaders().getLocation() != null 
                    ? response.getHeaders().getLocation().toString() : "";
                log.warn("爱企查返回重定向，可能触发了验证码: {}", location);
                if (location.contains("captcha") || location.contains("wappass")) {
                    return SearchResult.error("爱企查需要验证码验证，请在浏览器中完成验证后重试");
                }
                return SearchResult.error("爱企查服务暂时不可用，请稍后重试");
            } else {
                return SearchResult.error("搜索请求失败: " + response.getStatusCode());
            }
        } catch (org.springframework.web.client.ResourceAccessException e) {
            log.error("爱企查连接失败: {}", e.getMessage());
            if (e.getMessage() != null && e.getMessage().contains("timed out")) {
                return SearchResult.error("连接爱企查超时，请检查网络或稍后重试");
            }
            return SearchResult.error("无法连接爱企查服务，请检查网络");
        } catch (Exception e) {
            log.error("爱企查搜索失败", e);
            return SearchResult.error("搜索失败: " + e.getMessage());
        }
    }

    /**
     * 获取企业详情
     * 
     * @param pid 爱企查企业ID
     * @return 企业详情
     */
    public EnterpriseDetail getEnterpriseDetail(String pid) {
        String organizationId = OrganizationContext.getOrganizationId();
        Optional<String> cookieOpt = configService.getIqichaCookie(organizationId);
        
        if (cookieOpt.isEmpty() || StringUtils.isBlank(cookieOpt.get())) {
            return null;
        }

        try {
            String url = IQICHA_DETAIL_URL + "?pid=" + pid;

            HttpHeaders headers = new HttpHeaders();
            headers.set("Cookie", cookieOpt.get());
            headers.set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36");
            headers.set("Referer", "https://aiqicha.baidu.com/");
            headers.setAccept(List.of(MediaType.APPLICATION_JSON));

            HttpEntity<String> entity = new HttpEntity<>(headers);
            ResponseEntity<String> response = restTemplate.exchange(url, HttpMethod.GET, entity, String.class);

            if (response.getStatusCode() == HttpStatus.OK && response.getBody() != null) {
                return parseDetailResponse(response.getBody());
            }
        } catch (Exception e) {
            log.error("获取企业详情失败", e);
        }
        return null;
    }

    /**
     * 解析搜索响应
     */
    private SearchResult parseSearchResponse(String responseBody) {
        // 检查响应是否为空
        if (StringUtils.isBlank(responseBody)) {
            log.warn("爱企查返回空响应");
            return SearchResult.error("爱企查返回空响应");
        }

        // 检查是否返回了 HTML（可能是登录页面或错误页面）
        String trimmedBody = responseBody.trim();
        if (trimmedBody.startsWith("<") || trimmedBody.startsWith("<!")) {
            log.warn("爱企查返回了 HTML 页面，可能 Cookie 已过期。响应前200字符: {}",
                trimmedBody.substring(0, Math.min(200, trimmedBody.length())));
            return SearchResult.error("Cookie 已过期或无效，请重新配置爱企查 Cookie");
        }

        // 记录原始响应用于调试
        log.debug("爱企查原始响应: {}", trimmedBody.substring(0, Math.min(500, trimmedBody.length())));

        try {
            JsonNode root = objectMapper.readTree(responseBody);
            
            // 检查状态
            int status = root.path("status").asInt(-1);
            if (status != 0) {
                String msg = root.path("msg").asText("未知错误");
                log.warn("爱企查返回错误状态: {}, 消息: {}", status, msg);
                return SearchResult.error(msg);
            }

            JsonNode data = root.path("data");
            JsonNode resultList = data.path("resultList");
            
            List<EnterpriseItem> items = new ArrayList<>();
            if (resultList.isArray()) {
                for (JsonNode item : resultList) {
                    EnterpriseItem enterprise = new EnterpriseItem();
                    enterprise.setPid(item.path("pid").asText());
                    enterprise.setName(item.path("titleName").asText());
                    enterprise.setCreditCode(item.path("unifiedCode").asText());
                    enterprise.setLegalPerson(item.path("legalPerson").asText());
                    enterprise.setAddress(item.path("regAddr").asText());
                    enterprise.setStatus(item.path("openStatus").asText());
                    enterprise.setEstablishDate(item.path("startDate").asText());
                    enterprise.setRegisteredCapital(item.path("regCapital").asText());
                    items.add(enterprise);
                }
            }

            int total = data.path("total").asInt(0);
            log.info("爱企查搜索成功，返回 {} 条结果，总计 {} 条", items.size(), total);
            return SearchResult.success(items, total);
        } catch (com.fasterxml.jackson.core.JsonParseException e) {
            // JSON 解析失败，通常是因为返回了 HTML 页面
            log.error("解析搜索响应失败（JSON格式错误），响应内容前200字符: {}",
                responseBody.substring(0, Math.min(200, responseBody.length())), e);
            // 检查是否是 HTML 响应
            if (responseBody.contains("<html") || responseBody.contains("<!DOCTYPE")) {
                return SearchResult.error("Cookie 已过期或无效，请在系统设置中重新配置爱企查 Cookie");
            }
            return SearchResult.error("爱企查返回了无效的响应格式，请稍后重试");
        } catch (Exception e) {
            log.error("解析搜索响应失败，响应内容前200字符: {}",
                responseBody.substring(0, Math.min(200, responseBody.length())), e);
            return SearchResult.error("解析响应失败: " + e.getMessage());
        }
    }

    /**
     * 解析详情响应
     */
    private EnterpriseDetail parseDetailResponse(String responseBody) {
        try {
            JsonNode root = objectMapper.readTree(responseBody);
            
            int status = root.path("status").asInt(-1);
            if (status != 0) {
                return null;
            }

            JsonNode data = root.path("data");
            EnterpriseDetail detail = new EnterpriseDetail();
            detail.setPid(data.path("pid").asText());
            detail.setName(data.path("entName").asText());
            detail.setCreditCode(data.path("unifiedCode").asText());
            detail.setLegalPerson(data.path("legalPerson").asText());
            detail.setAddress(data.path("regAddr").asText());
            detail.setStatus(data.path("openStatus").asText());
            detail.setEstablishDate(data.path("startDate").asText());
            detail.setRegisteredCapital(data.path("regCapital").asText());
            detail.setIndustry(data.path("industry").asText());
            detail.setPhone(data.path("telephone").asText());
            detail.setEmail(data.path("email").asText());
            detail.setWebsite(data.path("website").asText());
            detail.setScope(data.path("scope").asText());
            
            return detail;
        } catch (Exception e) {
            log.error("解析详情响应失败", e);
            return null;
        }
    }

    // ==================== 内部类 ====================

    /**
     * 搜索结果
     */
    public static class SearchResult {
        private boolean success;
        private String message;
        private List<EnterpriseItem> items;
        private int total;

        public static SearchResult success(List<EnterpriseItem> items, int total) {
            SearchResult result = new SearchResult();
            result.success = true;
            result.items = items;
            result.total = total;
            return result;
        }

        public static SearchResult error(String message) {
            SearchResult result = new SearchResult();
            result.success = false;
            result.message = message;
            result.items = new ArrayList<>();
            result.total = 0;
            return result;
        }

        // Getters and Setters
        public boolean isSuccess() { return success; }
        public void setSuccess(boolean success) { this.success = success; }
        public String getMessage() { return message; }
        public void setMessage(String message) { this.message = message; }
        public List<EnterpriseItem> getItems() { return items; }
        public void setItems(List<EnterpriseItem> items) { this.items = items; }
        public int getTotal() { return total; }
        public void setTotal(int total) { this.total = total; }
    }

    /**
     * 企业搜索项
     */
    public static class EnterpriseItem {
        private String pid;
        private String name;
        private String creditCode;
        private String legalPerson;
        private String address;
        private String status;
        private String establishDate;
        private String registeredCapital;

        // Getters and Setters
        public String getPid() { return pid; }
        public void setPid(String pid) { this.pid = pid; }
        public String getName() { return name; }
        public void setName(String name) { this.name = name; }
        public String getCreditCode() { return creditCode; }
        public void setCreditCode(String creditCode) { this.creditCode = creditCode; }
        public String getLegalPerson() { return legalPerson; }
        public void setLegalPerson(String legalPerson) { this.legalPerson = legalPerson; }
        public String getAddress() { return address; }
        public void setAddress(String address) { this.address = address; }
        public String getStatus() { return status; }
        public void setStatus(String status) { this.status = status; }
        public String getEstablishDate() { return establishDate; }
        public void setEstablishDate(String establishDate) { this.establishDate = establishDate; }
        public String getRegisteredCapital() { return registeredCapital; }
        public void setRegisteredCapital(String registeredCapital) { this.registeredCapital = registeredCapital; }
    }

    /**
     * 企业详情
     */
    public static class EnterpriseDetail extends EnterpriseItem {
        private String industry;
        private String phone;
        private String email;
        private String website;
        private String scope;

        // Getters and Setters
        public String getIndustry() { return industry; }
        public void setIndustry(String industry) { this.industry = industry; }
        public String getPhone() { return phone; }
        public void setPhone(String phone) { this.phone = phone; }
        public String getEmail() { return email; }
        public void setEmail(String email) { this.email = email; }
        public String getWebsite() { return website; }
        public void setWebsite(String website) { this.website = website; }
        public String getScope() { return scope; }
        public void setScope(String scope) { this.scope = scope; }
    }
}
