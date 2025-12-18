-- ============================================
-- CRM 系统模拟数据清理脚本
-- 执行前请先备份数据库！
-- 仅用于测试环境，生产环境禁止执行！
-- ============================================

SET SESSION innodb_lock_wait_timeout = 7200;

-- 记录清理前数据量
SELECT '=== 清理前数据统计 ===' AS info;
SELECT 'sys_user' AS table_name, COUNT(*) AS count FROM sys_user
UNION ALL SELECT 'customer', COUNT(*) FROM customer
UNION ALL SELECT 'clue', COUNT(*) FROM clue
UNION ALL SELECT 'opportunity', COUNT(*) FROM opportunity
UNION ALL SELECT 'customer_contact', COUNT(*) FROM customer_contact
UNION ALL SELECT 'follow_up_record', COUNT(*) FROM follow_up_record;

-- 开始事务
START TRANSACTION;

-- ============================================
-- 1. 清理业务数据（按外键依赖顺序，从子表到主表）
-- ============================================

-- 1.1 清理跟进记录
DELETE FROM follow_up_record WHERE organization_id = '100001';

-- 1.2 清理跟进计划
DELETE FROM follow_up_plan WHERE organization_id = '100001';

-- 1.3 清理联系人
DELETE FROM customer_contact WHERE organization_id = '100001';

-- 1.4 清理商机
DELETE FROM opportunity WHERE organization_id = '100001';

-- 1.5 清理线索
DELETE FROM clue WHERE organization_id = '100001';

-- 1.6 清理客户
DELETE FROM customer WHERE organization_id = '100001';

-- ============================================
-- 2. 清理企业集成相关数据
-- ============================================

-- 2.1 清理企查查同步日志
DELETE FROM iqicha_sync_log WHERE 1=1;

-- 2.2 清理企业画像
DELETE FROM enterprise_profile WHERE 1=1;

-- 2.3 清理客户爱企查画像
DELETE FROM customer_aiqicha_profile WHERE 1=1;

-- 2.4 清理公司画像
DELETE FROM company_portrait WHERE 1=1;

-- 2.5 清理 AI 生成日志
DELETE FROM ai_generation_log WHERE 1=1;

-- 2.6 清理话术（保留模板）
DELETE FROM call_script WHERE 1=1;

-- ============================================
-- 3. 清理系统数据（可选）
-- ============================================

-- 3.1 清理消息通知
DELETE FROM sys_notification WHERE organization_id = '100001';

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
UNION ALL SELECT 'customer', COUNT(*) FROM customer
UNION ALL SELECT 'clue', COUNT(*) FROM clue
UNION ALL SELECT 'opportunity', COUNT(*) FROM opportunity
UNION ALL SELECT 'customer_contact', COUNT(*) FROM customer_contact
UNION ALL SELECT 'follow_up_record', COUNT(*) FROM follow_up_record;

SELECT '=== 保留的用户 ===' AS info;
SELECT id, name, phone, email FROM sys_user;

SELECT 'Mock data cleanup completed!' AS result;
