-- set innodb lock wait timeout
SET SESSION innodb_lock_wait_timeout = 7200;

-- =====================================================
-- AI模型定价表
-- =====================================================
CREATE TABLE ai_model_pricing (
    `id`                VARCHAR(32)    NOT NULL COMMENT 'id',
    `provider_code`     VARCHAR(32)    NOT NULL COMMENT '提供商代码(openai/aliyun/claude)',
    `model_code`        VARCHAR(64)    NOT NULL COMMENT '模型代码(gpt-4/qwen-max)',
    `model_name`        VARCHAR(128)   DEFAULT NULL COMMENT '模型显示名称',
    `input_price`       DECIMAL(16,8)  NOT NULL COMMENT '输入Token价格',
    `output_price`      DECIMAL(16,8)  NOT NULL COMMENT '输出Token价格',
    `unit`              INT            NOT NULL DEFAULT 1000 COMMENT '计价单位(默认1000 tokens)',
    `currency`          VARCHAR(8)     NOT NULL DEFAULT 'USD' COMMENT '货币单位(USD/CNY)',
    `enabled`           BIT(1)         NOT NULL DEFAULT 1 COMMENT '是否启用',
    `description`       VARCHAR(512)   DEFAULT NULL COMMENT '描述',
    `create_time`       BIGINT         NOT NULL COMMENT '创建时间',
    `update_time`       BIGINT         NOT NULL COMMENT '更新时间',
    `create_user`       VARCHAR(32)    NOT NULL COMMENT '创建人',
    `update_user`       VARCHAR(32)    NOT NULL COMMENT '更新人',
    PRIMARY KEY (id),
    UNIQUE KEY uk_provider_model (provider_code, model_code),
    KEY idx_enabled (enabled),
    KEY idx_provider (provider_code)
) COMMENT = 'AI模型定价配置'
ENGINE = InnoDB
DEFAULT CHARSET = utf8mb4
COLLATE = utf8mb4_general_ci;

-- =====================================================
-- 插入默认定价数据
-- =====================================================

-- OpenAI 模型定价 (价格单位: USD per 1000 tokens)
INSERT INTO ai_model_pricing (id, provider_code, model_code, model_name, input_price, output_price, unit, currency, enabled, description, create_time, update_time, create_user, update_user)
VALUES
-- GPT-4 系列
('ai_pricing_001', 'openai', 'gpt-4', 'GPT-4', 0.03000000, 0.06000000, 1000, 'USD', 1, 'GPT-4 8K context', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000, 'system', 'system'),
('ai_pricing_002', 'openai', 'gpt-4-32k', 'GPT-4 32K', 0.06000000, 0.12000000, 1000, 'USD', 1, 'GPT-4 32K context', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000, 'system', 'system'),
('ai_pricing_003', 'openai', 'gpt-4-turbo', 'GPT-4 Turbo', 0.01000000, 0.03000000, 1000, 'USD', 1, 'GPT-4 Turbo 128K context', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000, 'system', 'system'),

-- GPT-3.5 系列
('ai_pricing_004', 'openai', 'gpt-3.5-turbo', 'GPT-3.5 Turbo', 0.00150000, 0.00200000, 1000, 'USD', 1, 'GPT-3.5 Turbo 16K context', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000, 'system', 'system'),
('ai_pricing_005', 'openai', 'gpt-3.5-turbo-16k', 'GPT-3.5 Turbo 16K', 0.00300000, 0.00400000, 1000, 'USD', 1, 'GPT-3.5 Turbo 16K context', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000, 'system', 'system');

-- 阿里云通义千问模型定价 (价格单位: CNY per 1000 tokens)
INSERT INTO ai_model_pricing (id, provider_code, model_code, model_name, input_price, output_price, unit, currency, enabled, description, create_time, update_time, create_user, update_user)
VALUES
('ai_pricing_101', 'aliyun', 'qwen-max', '通义千问Max', 0.04000000, 0.12000000, 1000, 'CNY', 1, '通义千问Max模型', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000, 'system', 'system'),
('ai_pricing_102', 'aliyun', 'qwen-plus', '通义千问Plus', 0.00800000, 0.02000000, 1000, 'CNY', 1, '通义千问Plus模型', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000, 'system', 'system'),
('ai_pricing_103', 'aliyun', 'qwen-turbo', '通义千问Turbo', 0.00300000, 0.00600000, 1000, 'CNY', 1, '通义千问Turbo模型', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000, 'system', 'system');

-- set innodb lock wait timeout to default
SET SESSION innodb_lock_wait_timeout = DEFAULT;
