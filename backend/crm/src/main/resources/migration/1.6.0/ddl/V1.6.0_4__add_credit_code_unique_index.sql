-- Flyway Migration: Add Credit Code Unique Index
-- Version: 1.6.0_4
-- Description: 为 enterprise_profile 表的 credit_code 字段添加唯一索引约束
-- Date: 2024-12-27
-- Requirements: 1.5, 2.4

-- Step 1: 验证没有重复记录
SET @duplicate_count = (
    SELECT COUNT(*)
    FROM (
        SELECT credit_code, COUNT(*) as cnt
        FROM enterprise_profile
        WHERE credit_code IS NOT NULL AND credit_code != ''
        GROUP BY credit_code
        HAVING COUNT(*) > 1
    ) AS duplicates
);

-- Step 2: 验证没有重复（如果有重复，唯一索引创建会失败）
SELECT 
    @duplicate_count AS duplicate_count,
    CASE 
        WHEN @duplicate_count > 0 THEN 'ERROR: Cannot proceed - duplicates exist'
        ELSE 'Validation passed'
    END AS validation_status;

-- Step 3: 添加唯一索引
-- 注意：MySQL 的唯一索引允许多个 NULL 值，这符合我们的需求
ALTER TABLE enterprise_profile
ADD UNIQUE INDEX uk_credit_code (credit_code);

-- Step 4: 验证索引创建成功
SELECT 
    COUNT(*) AS index_exists,
    CASE 
        WHEN COUNT(*) > 0 THEN 'Index created successfully'
        ELSE 'ERROR: Index creation failed'
    END AS index_status
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND table_name = 'enterprise_profile'
  AND index_name = 'uk_credit_code';

-- 输出统计信息
SELECT 
    'Migration Summary' AS info,
    'uk_credit_code' AS index_name,
    'UNIQUE' AS index_type,
    'credit_code' AS indexed_column;
