-- ============================================
-- CRM 系统测试用户创建脚本
-- 密码: Cordys@2024 (MD5 加密)
-- ============================================

SET SESSION innodb_lock_wait_timeout = 7200;

-- 开始事务
START TRANSACTION;

-- ============================================
-- 1. 创建测试用户
-- 密码 Cordys@2024 的 MD5 值
-- ============================================

-- 计算密码 MD5
SET @password_hash = MD5('Cordys@2024');
SET @current_time = UNIX_TIMESTAMP() * 1000;

-- 用户1: 13902213704 - 销售经理
INSERT INTO sys_user (id, name, phone, email, password, gender, language, last_organization_id, create_time, update_time, create_user, update_user)
VALUES ('user_13902213704', '张经理', '13902213704', '13902213704@cordys-crm.io', @password_hash, 0, 'zh_CN', '100001', @current_time, @current_time, 'admin', 'admin')
ON DUPLICATE KEY UPDATE 
    name = VALUES(name),
    password = VALUES(password),
    update_time = VALUES(update_time);

-- 用户2: 18911537991 - 销售专员
INSERT INTO sys_user (id, name, phone, email, password, gender, language, last_organization_id, create_time, update_time, create_user, update_user)
VALUES ('user_18911537991', '李销售', '18911537991', '18911537991@cordys-crm.io', @password_hash, 0, 'zh_CN', '100001', @current_time + 1, @current_time + 1, 'admin', 'admin')
ON DUPLICATE KEY UPDATE 
    name = VALUES(name),
    password = VALUES(password),
    update_time = VALUES(update_time);

-- 用户3: 15510322935 - 销售专员
INSERT INTO sys_user (id, name, phone, email, password, gender, language, last_organization_id, create_time, update_time, create_user, update_user)
VALUES ('user_15510322935', '王销售', '15510322935', '15510322935@cordys-crm.io', @password_hash, 1, 'zh_CN', '100001', @current_time + 2, @current_time + 2, 'admin', 'admin')
ON DUPLICATE KEY UPDATE 
    name = VALUES(name),
    password = VALUES(password),
    update_time = VALUES(update_time);

-- 用户4: 13762420030 - 销售专员
INSERT INTO sys_user (id, name, phone, email, password, gender, language, last_organization_id, create_time, update_time, create_user, update_user)
VALUES ('user_13762420030', '赵销售', '13762420030', '13762420030@cordys-crm.io', @password_hash, 0, 'zh_CN', '100001', @current_time + 3, @current_time + 3, 'admin', 'admin')
ON DUPLICATE KEY UPDATE 
    name = VALUES(name),
    password = VALUES(password),
    update_time = VALUES(update_time);

-- 用户5: 18942021073 - 销售专员
INSERT INTO sys_user (id, name, phone, email, password, gender, language, last_organization_id, create_time, update_time, create_user, update_user)
VALUES ('user_18942021073', '钱销售', '18942021073', '18942021073@cordys-crm.io', @password_hash, 1, 'zh_CN', '100001', @current_time + 4, @current_time + 4, 'admin', 'admin')
ON DUPLICATE KEY UPDATE 
    name = VALUES(name),
    password = VALUES(password),
    update_time = VALUES(update_time);

-- 用户6: 13716013451 - 组织管理员
INSERT INTO sys_user (id, name, phone, email, password, gender, language, last_organization_id, create_time, update_time, create_user, update_user)
VALUES ('user_13716013451', '孙管理', '13716013451', '13716013451@cordys-crm.io', @password_hash, 0, 'zh_CN', '100001', @current_time + 5, @current_time + 5, 'admin', 'admin')
ON DUPLICATE KEY UPDATE 
    name = VALUES(name),
    password = VALUES(password),
    update_time = VALUES(update_time);

-- ============================================
-- 2. 分配角色
-- ============================================

-- 用户1: 销售经理
INSERT INTO sys_user_role (id, role_id, user_id, create_time, update_time, create_user, update_user)
VALUES ('sur_13902213704', 'sales_manager', 'user_13902213704', @current_time, @current_time, 'admin', 'admin')
ON DUPLICATE KEY UPDATE update_time = VALUES(update_time);

-- 用户2-5: 销售专员
INSERT INTO sys_user_role (id, role_id, user_id, create_time, update_time, create_user, update_user)
VALUES ('sur_18911537991', 'sales_staff', 'user_18911537991', @current_time + 1, @current_time + 1, 'admin', 'admin')
ON DUPLICATE KEY UPDATE update_time = VALUES(update_time);

INSERT INTO sys_user_role (id, role_id, user_id, create_time, update_time, create_user, update_user)
VALUES ('sur_15510322935', 'sales_staff', 'user_15510322935', @current_time + 2, @current_time + 2, 'admin', 'admin')
ON DUPLICATE KEY UPDATE update_time = VALUES(update_time);

INSERT INTO sys_user_role (id, role_id, user_id, create_time, update_time, create_user, update_user)
VALUES ('sur_13762420030', 'sales_staff', 'user_13762420030', @current_time + 3, @current_time + 3, 'admin', 'admin')
ON DUPLICATE KEY UPDATE update_time = VALUES(update_time);

INSERT INTO sys_user_role (id, role_id, user_id, create_time, update_time, create_user, update_user)
VALUES ('sur_18942021073', 'sales_staff', 'user_18942021073', @current_time + 4, @current_time + 4, 'admin', 'admin')
ON DUPLICATE KEY UPDATE update_time = VALUES(update_time);

-- 用户6: 组织管理员
INSERT INTO sys_user_role (id, role_id, user_id, create_time, update_time, create_user, update_user)
VALUES ('sur_13716013451', 'org_admin', 'user_13716013451', @current_time + 5, @current_time + 5, 'admin', 'admin')
ON DUPLICATE KEY UPDATE update_time = VALUES(update_time);

-- ============================================
-- 3. 分配组织
-- ============================================

-- 将所有测试用户分配到组织 100001
INSERT INTO sys_organization_user (id, organization_id, user_id, create_time, update_time, create_user, update_user)
VALUES ('ou_user_13902213704', '100001', 'user_13902213704', @current_time, @current_time, 'admin', 'admin')
ON DUPLICATE KEY UPDATE update_time = VALUES(update_time);

INSERT INTO sys_organization_user (id, organization_id, user_id, create_time, update_time, create_user, update_user)
VALUES ('ou_user_18911537991', '100001', 'user_18911537991', @current_time + 1, @current_time + 1, 'admin', 'admin')
ON DUPLICATE KEY UPDATE update_time = VALUES(update_time);

INSERT INTO sys_organization_user (id, organization_id, user_id, create_time, update_time, create_user, update_user)
VALUES ('ou_user_15510322935', '100001', 'user_15510322935', @current_time + 2, @current_time + 2, 'admin', 'admin')
ON DUPLICATE KEY UPDATE update_time = VALUES(update_time);

INSERT INTO sys_organization_user (id, organization_id, user_id, create_time, update_time, create_user, update_user)
VALUES ('ou_user_13762420030', '100001', 'user_13762420030', @current_time + 3, @current_time + 3, 'admin', 'admin')
ON DUPLICATE KEY UPDATE update_time = VALUES(update_time);

INSERT INTO sys_organization_user (id, organization_id, user_id, create_time, update_time, create_user, update_user)
VALUES ('ou_user_18942021073', '100001', 'user_18942021073', @current_time + 4, @current_time + 4, 'admin', 'admin')
ON DUPLICATE KEY UPDATE update_time = VALUES(update_time);

INSERT INTO sys_organization_user (id, organization_id, user_id, create_time, update_time, create_user, update_user)
VALUES ('ou_user_13716013451', '100001', 'user_13716013451', @current_time + 5, @current_time + 5, 'admin', 'admin')
ON DUPLICATE KEY UPDATE update_time = VALUES(update_time);

-- 提交事务
COMMIT;

-- 恢复默认超时
SET SESSION innodb_lock_wait_timeout = DEFAULT;

-- 显示创建结果
SELECT 'Test users created successfully!' AS result;
SELECT id, name, phone, email FROM sys_user WHERE id LIKE 'user_%' OR id = 'admin';
SELECT ur.user_id, r.name AS role_name FROM sys_user_role ur JOIN sys_role r ON ur.role_id = r.id WHERE ur.user_id LIKE 'user_%';
