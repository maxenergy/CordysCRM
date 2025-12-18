-- set innodb lock wait timeout
SET SESSION innodb_lock_wait_timeout = 7200;

-- =====================================================
-- Fix enterprise_profile.reg_date type: DATE -> BIGINT(ms)
-- =====================================================

ALTER TABLE enterprise_profile
    ADD COLUMN `reg_date_tmp` BIGINT DEFAULT NULL COMMENT '成立日期' AFTER `reg_capital`;

UPDATE enterprise_profile
SET reg_date_tmp =
    CASE
        WHEN reg_date IS NULL THEN NULL
        ELSE UNIX_TIMESTAMP(reg_date) * 1000
    END
WHERE reg_date IS NOT NULL;

ALTER TABLE enterprise_profile
    DROP COLUMN `reg_date`,
    CHANGE COLUMN `reg_date_tmp` `reg_date` BIGINT DEFAULT NULL COMMENT '成立日期';

-- set innodb lock wait timeout to default
SET SESSION innodb_lock_wait_timeout = DEFAULT;
