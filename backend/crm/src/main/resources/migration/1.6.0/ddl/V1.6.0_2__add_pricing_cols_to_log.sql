-- set innodb lock wait timeout
SET SESSION innodb_lock_wait_timeout = 7200;

-- =====================================================
-- Add pricing columns to ai_generation_log
-- =====================================================
ALTER TABLE ai_generation_log
ADD COLUMN input_price DECIMAL(16,8) DEFAULT NULL COMMENT 'Input Price (per unit)',
ADD COLUMN output_price DECIMAL(16,8) DEFAULT NULL COMMENT 'Output Price (per unit)',
ADD COLUMN currency VARCHAR(8) DEFAULT NULL COMMENT 'Currency (USD/CNY)';

-- set innodb lock wait timeout to default
SET SESSION innodb_lock_wait_timeout = DEFAULT;
