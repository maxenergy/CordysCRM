-- Flyway Migration: Cleanup Duplicate Credit Codes
-- Version: 1.6.0_3
-- Description: 清理重复的企业信用代码记录，为添加唯一索引做准备
-- Date: 2024-12-27
-- Requirements: 2.1, 2.2, 2.3, 2.4

-- Step 1: 创建备份表
CREATE TABLE IF NOT EXISTS enterprise_profile_backup_20241227 AS 
SELECT * FROM enterprise_profile;

-- Step 2: 创建临时表记录重复信息
CREATE TEMPORARY TABLE IF NOT EXISTS duplicate_credit_codes AS
SELECT 
    credit_code, 
    COUNT(*) as duplicate_count, 
    MIN(id) as keep_id,
    GROUP_CONCAT(id ORDER BY id) as all_ids
FROM enterprise_profile
WHERE credit_code IS NOT NULL 
  AND credit_code != ''
GROUP BY credit_code
HAVING COUNT(*) > 1;

-- Step 3: 记录将要删除的记录数
SET @delete_count = (
    SELECT SUM(duplicate_count - 1) 
    FROM duplicate_credit_codes
);

-- Step 4: 删除重复记录（保留 ID 最小的记录）
DELETE FROM enterprise_profile
WHERE id IN (
    SELECT ep.id
    FROM (
        SELECT id, credit_code
        FROM enterprise_profile
    ) ep
    INNER JOIN duplicate_credit_codes dcc 
        ON ep.credit_code = dcc.credit_code
    WHERE ep.id != dcc.keep_id
);

-- Step 5: 验证清理结果
SET @remaining_duplicates = (
    SELECT COUNT(*)
    FROM (
        SELECT credit_code, COUNT(*) as cnt
        FROM enterprise_profile
        WHERE credit_code IS NOT NULL AND credit_code != ''
        GROUP BY credit_code
        HAVING COUNT(*) > 1
    ) AS check_duplicates
);

-- Step 6: 验证清理结果
-- 如果仍有重复，迁移将在下一步失败（添加唯一索引时）
SELECT 
    @remaining_duplicates AS remaining_duplicates_count,
    CASE 
        WHEN @remaining_duplicates > 0 THEN 'WARNING: Duplicates still exist'
        ELSE 'Cleanup successful'
    END AS migration_status;

-- Step 7: 记录迁移日志（如果有 migration_log 表）
-- INSERT INTO migration_log (version, description, affected_rows, created_at)
-- VALUES ('1.6.0_3', 'Cleanup duplicate credit codes', COALESCE(@delete_count, 0), NOW());

-- 输出统计信息
SELECT 
    'Migration Summary' AS info,
    COALESCE(@delete_count, 0) AS deleted_records,
    @remaining_duplicates AS remaining_duplicates;
