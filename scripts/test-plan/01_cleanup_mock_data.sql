-- ============================================
-- CRM 系统模拟数据清理脚本
-- 执行前请先备份数据库！
-- 仅用于测试环境，生产环境禁止执行！
-- ============================================

SET SESSION innodb_lock_wait_timeout = 7200;

-- 记录清理前数据量
SELECT '=== 清理前数据统计 ===' AS info;
SELECT 'sys_user' AS table_name, COUNT(*) AS count FROM sys_user
UNION ALL SELECT 'crm_customer', COUNT(*) FROM crm_customer
UNION ALL SELECT 'crm_clue', COUNT(*) FROM crm_clue
UNION ALL SELECT 'crm_business', COUNT(*) FROM crm_business
UNION ALL SELECT 'crm_contact', COUNT(*) FROM crm_contact
UNION ALL SELECT 'crm_follow_record', COUNT(*) FROM crm_follow_record;

-- 开始事务
START TRANSACTION;

-- ============================================
-- 1. 清理业务数据（按外键依赖顺序，从子表到主表）
-- ============================================

-- 1.1 清理跟进记录（最底层）
DELETE FROM crm_follow_record WHERE organization_id = '100001';

-- 1.2 清理联系人
DELETE FROM crm_contact WHERE organization_id = '100001';

-- 1.3 清理客户标签关系（如存在）
-- DELETE FROM crm_customer_tag WHERE customer_id IN (SELECT id FROM crm_customer WHERE organization_id = '100001');

-- 1.4 清理商机
DELETE FROM crm_business WHERE organization_id = '100001';

-- 1.5 清理线索
DELETE FROM crm_clue WHERE organization_id = '100001';

-- 1.6 清理客户
DELETE FROM crm_customer WHERE organization_id = '100001';

-- ============================================
-- 2. 清理企业集成相关数据
-- ============================================

-- 2.1 清理企业导入记录
DELETE FROM enterprise_import_log WHERE 1=1;

-- 2.2 清理企业画像
DELETE FROM enterprise_profile WHERE 1=1;

-- 2.3 清理 AI 生成日志
DELETE FROM ai_generation_log WHERE 1=1;

-- 2.4 清理话术模板（保留系统模板）
DELETE FROM call_script_template WHERE is_system = 0 OR is_system IS NULL;

-- ============================================
-- 3. 清理系统数据（可选）
-- ============================================

-- 3.1 清理消息通知（保留配置）
DELETE FROM sys_message WHERE organization_id = '100001';

-- 3.2 清理操作日志（测试环境建议清理）
-- DELETE FROM sys_operation_log WHERE organization_id = '100001';

-- ============================================
-- 4. 清理测试用户（保留 admin）
-- ============================================

-- 4.1 清理用户角色关联（先删关联）
DELETE FROM sys_user_role WHERE user_id NOT IN ('admin');

-- 4.2 清理组织用户关联
DELETE FROM sys_organization_user WHERE user_id NOT IN ('admin');

-- 4.3 清理用户扩展信息
DELETE FROM sys_user_extend WHERE id NOT IN ('admin');

-- 4.4 清理用户（保留 admin）
DELETE FROM sys_user WHERE id NOT IN ('admin');

-- 提交事务
COMMIT;

-- 恢复默认超时
SET SESSION innodb_lock_wait_timeout = DEFAULT;

-- ============================================
-- 5. 清理后验证
-- ============================================
SELECT '=== 清理后数据统计 ===' AS info;
SELECT 'sys_user' AS table_name, COUNT(*) AS count FROM sys_user
UNION ALL SELECT 'crm_customer', COUNT(*) FROM crm_customer
UNION ALL SELECT 'crm_clue', COUNT(*) FROM crm_clue
UNION ALL SELECT 'crm_business', COUNT(*) FROM crm_business
UNION ALL SELECT 'crm_contact', COUNT(*) FROM crm_contact
UNION ALL SELECT 'crm_follow_record', COUNT(*) FROM crm_follow_record;

SELECT '=== 保留的用户 ===' AS info;
SELECT id, name, phone, email FROM sys_user;

SELECT 'Mock data cleanup completed!' AS result;
