package cn.cordys.crm.system.controller;

import cn.cordys.common.constants.UserSource;
import cn.cordys.common.exception.GenericException;
import cn.cordys.common.request.LoginRequest;
import cn.cordys.common.util.Translator;
import cn.cordys.common.util.rsa.RsaKey;
import cn.cordys.common.util.rsa.RsaUtils;
import cn.cordys.context.OrganizationContext;
import cn.cordys.crm.system.service.UserLoginService;
import cn.cordys.security.SessionConstants;
import cn.cordys.security.SessionUser;
import cn.cordys.security.SessionUtils;
import cn.cordys.security.UserDTO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.annotation.Resource;
import org.apache.commons.lang3.StringUtils;
import org.apache.commons.lang3.Strings;
import org.apache.shiro.SecurityUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.session.Session;
import org.springframework.session.data.redis.RedisIndexedSessionRepository;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

/**
 * 登录控制器，负责处理用户登录、校验和退出操作。
 * <p>
 * 该控制器包含检查是否已登录、获取公钥、用户登录和退出登录功能。
 * </p>
 */
@RestController
@RequestMapping
@Tag(name = "登录")
public class LoginController {

    private static final Logger log = LoggerFactory.getLogger(LoginController.class);
    private static final String SESSION_AUTH_PREFIX = "Session ";
    private static final String BEARER_AUTH_PREFIX = "Bearer ";

    @Resource
    private UserLoginService userLoginService;

    @Resource
    private RedisIndexedSessionRepository redisIndexedSessionRepository;

    /**
     * 检查用户是否已登录。
     *
     * @return 返回用户会话信息，未登录则返回 401 错误。
     */
    @GetMapping(value = "/is-login")
    @Operation(summary = "是否登录")
    public SessionUser isLogin() {
        SessionUser user = SessionUtils.getUser();
        if (user != null) {
            // 检查当前组织的手机认证配置
            userLoginService.checkMobileAuthConfig(OrganizationContext.getOrganizationId());

            UserDTO userDTO = userLoginService.authenticateUser(user.getId());
            SessionUser sessionUser = SessionUser.fromUser(userDTO, SessionUtils.getSessionId());
            SessionUtils.putUser(sessionUser);
            return sessionUser;
        }
        return null;
    }

    /**
     * 获取当前用户信息（用于 Chrome 扩展等外部客户端）。
     * <p>
     * 支持两种认证方式：
     * 1. Authorization: Bearer {sessionId}
     * 2. Authorization: Session {sessionId}
     * </p>
     *
     * @param authorization Authorization 请求头
     * @return 当前用户信息；未认证返回 401
     */
    @GetMapping(value = "/api/user/current")
    @Operation(summary = "获取当前用户（Bearer/Session Token）")
    public ResponseEntity<SessionUser> currentUser(
            @RequestHeader(value = "Authorization", required = false) String authorization) {
        return doGetCurrentUser(authorization);
    }

    /**
     * 获取当前用户信息（公开端点，用于 Chrome 扩展等外部客户端）。
     * <p>
     * 这是 /api/user/current 的别名，使用 /anonymous/ 前缀以绕过 Shiro 认证。
     * </p>
     *
     * @param authorization Authorization 请求头
     * @return 当前用户信息；未认证返回 401
     */
    @GetMapping(value = "/anonymous/user/current")
    @Operation(summary = "获取当前用户（公开端点）")
    public ResponseEntity<SessionUser> currentUserPublic(
            @RequestHeader(value = "Authorization", required = false) String authorization) {
        return doGetCurrentUser(authorization);
    }

    /**
     * 获取当前用户信息的内部实现。
     */
    private ResponseEntity<SessionUser> doGetCurrentUser(String authorization) {
        String sessionId = extractSessionId(authorization);
        if (StringUtils.isBlank(sessionId)) {
            log.debug("[currentUser] Authorization header is missing or invalid");
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        try {
            Session session = redisIndexedSessionRepository.findById(sessionId);
            if (session == null) {
                log.debug("[currentUser] Session not found: {}...{}", 
                        maskSessionId(sessionId), sessionId.substring(sessionId.length() - 4));
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
            }

            SessionUser sessionUser = session.getAttribute(SessionConstants.ATTR_USER);
            if (sessionUser == null || StringUtils.isBlank(sessionUser.getId())) {
                log.debug("[currentUser] No valid user in session");
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
            }

            // 确保返回的 sessionId 与请求一致
            sessionUser.setSessionId(sessionId);
            log.debug("[currentUser] User authenticated: {}", sessionUser.getId());
            return ResponseEntity.ok(sessionUser);
        } catch (Exception e) {
            log.error("[currentUser] Error validating session: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
    }

    /**
     * 从 Authorization 头中提取 Session ID。
     * 支持大小写不敏感的 Bearer/Session 前缀。
     */
    private String extractSessionId(String authorization) {
        if (StringUtils.isBlank(authorization)) {
            return null;
        }
        String trimmed = authorization.trim();
        if (StringUtils.startsWithIgnoreCase(trimmed, BEARER_AUTH_PREFIX)) {
            return StringUtils.trimToNull(trimmed.substring(BEARER_AUTH_PREFIX.length()));
        }
        if (StringUtils.startsWithIgnoreCase(trimmed, SESSION_AUTH_PREFIX)) {
            return StringUtils.trimToNull(trimmed.substring(SESSION_AUTH_PREFIX.length()));
        }
        return null;
    }

    /**
     * 对 Session ID 进行脱敏处理，只保留前4位。
     */
    private String maskSessionId(String sessionId) {
        if (sessionId == null || sessionId.length() <= 8) {
            return "****";
        }
        return sessionId.substring(0, 4);
    }

    /**
     * 获取 RSA 公钥。
     *
     * @return 返回 RSA 公钥。
     *
     * @throws Exception 可能抛出的异常。
     */
    @GetMapping(value = "/get-key")
    @Operation(summary = "获取公钥")
    public String getKey() throws Exception {
        RsaKey rsaKey = RsaUtils.getRsaKey();
        return rsaKey.getPublicKey();
    }

    /**
     * 用户登录。
     *
     * @param request 登录请求对象，包含用户名和密码。
     *
     * @return 登录结果。
     *
     * @throws GenericException 如果已登录且当前用户与请求用户名不同，抛出异常。
     */
    @PostMapping(value = "/login")
    @Operation(summary = "登录")
    public SessionUser login(@Validated @RequestBody LoginRequest request) {
        SessionUser sessionUser = SessionUtils.getUser();
        if (sessionUser != null) {
            // 如果当前用户已登录且用户名与请求用户名不匹配，抛出异常
            if (!Strings.CS.equals(sessionUser.getId(), request.getUsername())) {
                throw new GenericException(Translator.get("please_logout_current_user"));
            }
        }
        // 设置认证方式为 LOCAL
        SecurityUtils.getSubject().getSession().setAttribute("authenticate", UserSource.LOCAL.name());
        return userLoginService.login(request);
    }

    /**
     * 退出登录。
     *
     * @return 返回退出成功信息。
     */
    @GetMapping(value = "/logout")
    @Operation(summary = "退出登录")
    public String logout() {
        if (SessionUtils.getUser() == null) {
            return "logout success";
        }
        // 退出当前会话
        SecurityUtils.getSubject().logout();
        return "logout success";
    }
}
