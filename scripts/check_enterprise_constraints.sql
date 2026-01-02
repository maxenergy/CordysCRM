-- 企业表约束检查脚本
-- 用途：检查 enterprise_profile 表的约束、索引和数据完整性

-- ========================================
-- 1. 查看表结构和约束
-- ========================================
SHOW CREATE TABLE enterprise_profile\G

-- ========================================
-- 2. 检查唯一约束冲突
-- ========================================
SELECT 
    '检查 credit_code 重复' AS check_type,
    credit_code,
    organization_id,
    COUNT(*) AS duplicate_count,
    GROUP_CONCAT(id) AS duplicate_ids
FROM enterprise_profile
GROUP BY credit_code, organization_id
HAVING COUNT(*) > 1;

-- ========================================
-- 3. 检查外键关联（customer_id）
-- ========================================
SELECT 
    '检查 customer_id 外键' AS check_type,
    ep.id AS profile_id,
    ep.customer_id,
    ep.company_name
FROM enterprise_profile ep
LEFT JOIN customer c ON ep.customer_id = c.id
WHERE c.id IS NULL
LIMIT 10;

-- ========================================
-- 4. 检查字段长度（可能超限的字段）
-- ========================================
SELECT 
    '检查字段长度' AS check_type,
    id,
    company_name,
    LENGTH(shareholders) AS shareholders_length,
    LENGTH(executives) AS executives_length,
    LENGTH(risks) AS risks_length,
    LENGTH(address) AS address_length
FROM enterprise_profile
WHERE 
    LENGTH(shareholders) > 1000 
    OR LENGTH(executives) > 1000 
    OR LENGTH(risks) > 1000
    OR LENGTH(address) > 500
LIMIT 10;

-- ========================================
-- 5. 检查日期字段
-- ========================================
SELECT 
    '检查日期字段' AS check_type,
    id,
    company_name,
    reg_date,
    DATE_FORMAT(reg_date, '%Y-%m-%d') AS formatted_date,
    YEAR(reg_date) AS year,
    CASE 
        WHEN reg_date IS NULL THEN 'NULL'
        WHEN YEAR(reg_date) < 1900 THEN 'TOO_OLD'
        WHEN YEAR(reg_date) > 2100 THEN 'TOO_NEW'
        ELSE 'OK'
    END AS date_status
FROM enterprise_profile
WHERE 
    reg_date IS NULL 
    OR YEAR(reg_date) < 1900 
    OR YEAR(reg_date) > 2100
LIMIT 10;

-- ========================================
-- 6. 检查最近导入的企业
-- ========================================
SELECT 
    '最近导入的企业' AS check_type,
    id,
    customer_id,
    company_name,
    credit_code,
    reg_date,
    DATE_FORMAT(reg_date, '%Y-%m-%d') AS formatted_date,
    FROM_UNIXTIME(create_time/1000) AS create_time_formatted
FROM enterprise_profile
WHERE create_time > UNIX_TIMESTAMP(NOW() - INTERVAL 1 HOUR) * 1000
ORDER BY create_time DESC
LIMIT 10;

-- ========================================
-- 7. 统计信息
-- ========================================
SELECT 
    '统计信息' AS info_type,
    COUNT(*) AS total_count,
    COUNT(DISTINCT credit_code) AS unique_credit_codes,
    COUNT(DISTINCT customer_id) AS unique_customers,
    COUNT(CASE WHEN reg_date IS NULL THEN 1 END) AS null_reg_date_count,
    COUNT(CASE WHEN LENGTH(shareholders) > 1000 THEN 1 END) AS long_shareholders_count,
    COUNT(CASE WHEN LENGTH(executives) > 1000 THEN 1 END) AS long_executives_count,
    COUNT(CASE WHEN LENGTH(risks) > 1000 THEN 1 END) AS long_risks_count
FROM enterprise_profile;

