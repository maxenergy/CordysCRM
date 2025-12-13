package cn.cordys.security;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 用于管理应用程序中过滤器链的工具类。
 * 包含加载基础过滤器链和忽略 CSRF 过滤器链的方法。
 */
public final class ShiroFilter {
    /**
     * 运行时动态追加的过滤规则（不保证顺序）。
     * 基础规则的顺序由 loadBaseFilterChain() 内部用 LinkedHashMap 固定。
     */
    private static final Map<String, String> EXTRA_FILTER_CHAIN_DEFINITION_MAP = new ConcurrentHashMap<>();

    // 私有构造函数防止实例化
    private ShiroFilter() {
        throw new AssertionError("工具类不应该被实例化");
    }

    /**
     * 添加URL过滤规则
     *
     * @param url  需要过滤的URL路径
     * @param rule 过滤规则
     */
    public static void putFilter(String url, String rule) {
        if (url != null && rule != null) {
            EXTRA_FILTER_CHAIN_DEFINITION_MAP.put(url, rule);
        }
    }

    /**
     * 加载应用程序的基础过滤器链。
     * 该过滤器链是一个映射，关联 URL 模式和过滤规则。
     * 使用 LinkedHashMap 保证顺序，确保具体规则在 /** 之前被匹配。
     *
     * @return 返回一个不可变Map，包含过滤器链定义，键是 URL 模式，值是关联的过滤规则。
     */
    public static Map<String, String> loadBaseFilterChain() {
        // 必须使用有序 Map，保证 Shiro 按插入顺序匹配时具体规则先于 /** 生效
        final Map<String, String> chain = new LinkedHashMap<>();
        
        // 静态资源路径
        addStaticResourceFilters(chain);

        // 认证相关路径
        addAuthenticationFilters(chain);

        // 其他公共路径
        addPublicPathFilters(chain);

        // 添加运行时动态追加的规则
        chain.putAll(EXTRA_FILTER_CHAIN_DEFINITION_MAP);
        
        return Collections.unmodifiableMap(chain);
    }


    /**
     * 添加静态资源过滤器规则
     */
    private static void addStaticResourceFilters(Map<String, String> chain) {
        chain.put("/web/**", "anon");
        chain.put("/mobile/**", "anon");
        chain.put("/static/**", "anon");
        chain.put("/templates/**", "anon");
        chain.put("/*.html", "anon");
        chain.put("/css/**", "anon");
        chain.put("/js/**", "anon");
        chain.put("/images/**", "anon");
        chain.put("/assets/**", "anon");
        chain.put("/fonts/**", "anon");
        chain.put("/favicon.ico", "anon");
        chain.put("/logo.*", "anon");
        chain.put("/base-display/**", "anon");
        chain.put("/cordys/**", "anon");
    }

    /**
     * 添加认证相关过滤器规则
     */
    private static void addAuthenticationFilters(Map<String, String> chain) {
        chain.put("/login", "anon");
        chain.put("/logout", "anon");
        chain.put("/is-login", "anon");
        // Chrome 扩展通过 Authorization: Bearer/Session {sessionId} 调用该接口
        // 使用 anon 跳过 Shiro 认证，在 Controller 中手动验证 Session ID
        chain.put("/api/user/current", "anon");
        chain.put("/api/user/current/**", "anon");
        chain.put("/get-key", "anon");
        chain.put("/403", "anon");
        chain.put("/sso/callback/**", "anon");
    }

    /**
     * 添加其他公共路径过滤器规则
     */
    private static void addPublicPathFilters(Map<String, String> chain) {
        chain.put("/display/info", "anon");
        chain.put("/pic/preview/**", "anon");
        chain.put("/attachment/preview/**", "anon");
        chain.put("/ui/display/preview", "anon");
        chain.put("/ui/display/info", "anon");
        chain.put("/anonymous/**", "anon");
        chain.put("/system/version/current", "anon");
        chain.put("/sse/subscribe/**", "anon");
        chain.put("/sse/close/**", "anon");
        chain.put("/sse/broadcast/**", "anon");
        chain.put("/organization/settings/third-party/types", "anon");
        chain.put("/organization/settings/third-party/get/**", "anon");
        chain.put("/organization/settings/third-party/sync/resource", "anon");
        chain.put("/license/validate/**", "anon");
        chain.put("/mcp/**", "anon");
        chain.put("/opportunity/stage/get", "anon");
    }

    /**
     * 返回忽略 CSRF 保护的过滤器链定义。
     *
     * @return 返回一个不可变Map，包含应绕过 CSRF 检查的 URL 路径的过滤器链定义。
     */
    public static Map<String, String> ignoreCsrfFilter() {
        final Map<String, String> chain = new LinkedHashMap<>();
        chain.put("/", "apikey, authc");
        chain.put("/language", "apikey, authc");
        chain.put("/mock", "apikey, authc");
        return Collections.unmodifiableMap(chain);
    }
}
