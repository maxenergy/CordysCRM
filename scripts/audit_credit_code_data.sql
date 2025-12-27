-- Data Audit Script for Enterprise Credit Code
-- Purpose: Analyze current state of credit_code field to identify data quality issues
-- Date: 2024-12-27

-- 1. Total Records
SELECT 'Total Records' AS metric, COUNT(*) AS count
FROM enterprise_profile;

-- 2. NULL Values
SELECT 'NULL Values' AS metric, COUNT(*) AS count
FROM enterprise_profile
WHERE credit_code IS NULL;

-- 3. Empty Strings
SELECT 'Empty Strings' AS metric, COUNT(*) AS count
FROM enterprise_profile
WHERE credit_code = '';

-- 4. Whitespace Issues (leading/trailing spaces)
SELECT 'Whitespace Issues' AS metric, COUNT(*) AS count
FROM enterprise_profile
WHERE credit_code != TRIM(credit_code);

-- 5. Lowercase Characters
SELECT 'Lowercase Characters' AS metric, COUNT(*) AS count
FROM enterprise_profile
WHERE credit_code != UPPER(credit_code);

-- 6. Length Anomalies (not 18 characters)
SELECT 'Length != 18' AS metric, COUNT(*) AS count
FROM enterprise_profile
WHERE credit_code IS NOT NULL 
  AND credit_code != ''
  AND CHAR_LENGTH(credit_code) != 18;

-- 7. Invalid Characters (not alphanumeric)
SELECT 'Invalid Characters' AS metric, COUNT(*) AS count
FROM enterprise_profile
WHERE credit_code IS NOT NULL
  AND credit_code != ''
  AND credit_code REGEXP '[^0-9A-Za-z]';

-- 8. Duplicate Credit Codes
SELECT 'Duplicate Groups' AS metric, COUNT(*) AS count
FROM (
    SELECT credit_code, COUNT(*) as cnt
    FROM enterprise_profile
    WHERE credit_code IS NOT NULL AND credit_code != ''
    GROUP BY credit_code
    HAVING COUNT(*) > 1
) AS duplicates;

-- 9. Total Duplicate Records
SELECT 'Total Duplicate Records' AS metric, SUM(cnt - 1) AS count
FROM (
    SELECT credit_code, COUNT(*) as cnt
    FROM enterprise_profile
    WHERE credit_code IS NOT NULL AND credit_code != ''
    GROUP BY credit_code
    HAVING COUNT(*) > 1
) AS duplicates;

-- 10. Detailed Duplicate List (Top 20)
SELECT 
    credit_code,
    COUNT(*) as duplicate_count,
    GROUP_CONCAT(id ORDER BY id) as duplicate_ids
FROM enterprise_profile
WHERE credit_code IS NOT NULL AND credit_code != ''
GROUP BY credit_code
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC
LIMIT 20;

-- 11. Sample Records with Issues
SELECT 
    id,
    credit_code,
    company_name,
    CASE
        WHEN credit_code IS NULL THEN 'NULL'
        WHEN credit_code = '' THEN 'EMPTY'
        WHEN credit_code != TRIM(credit_code) THEN 'WHITESPACE'
        WHEN credit_code != UPPER(credit_code) THEN 'LOWERCASE'
        WHEN CHAR_LENGTH(credit_code) != 18 THEN 'INVALID_LENGTH'
        WHEN credit_code REGEXP '[^0-9A-Za-z]' THEN 'INVALID_CHARS'
        ELSE 'OK'
    END AS issue_type
FROM enterprise_profile
WHERE credit_code IS NULL
   OR credit_code = ''
   OR credit_code != TRIM(credit_code)
   OR credit_code != UPPER(credit_code)
   OR CHAR_LENGTH(credit_code) != 18
   OR credit_code REGEXP '[^0-9A-Za-z]'
LIMIT 50;

-- 12. Summary Statistics
SELECT 
    COUNT(*) as total_records,
    SUM(CASE WHEN credit_code IS NULL OR credit_code = '' THEN 1 ELSE 0 END) as null_or_empty,
    SUM(CASE WHEN credit_code IS NOT NULL AND credit_code != '' THEN 1 ELSE 0 END) as valid_count,
    SUM(CASE WHEN credit_code != TRIM(credit_code) THEN 1 ELSE 0 END) as whitespace_issues,
    SUM(CASE WHEN credit_code != UPPER(credit_code) THEN 1 ELSE 0 END) as lowercase_issues,
    SUM(CASE WHEN CHAR_LENGTH(credit_code) != 18 THEN 1 ELSE 0 END) as length_issues,
    ROUND(100.0 * SUM(CASE WHEN credit_code IS NULL OR credit_code = '' THEN 1 ELSE 0 END) / COUNT(*), 2) as null_percentage
FROM enterprise_profile;
