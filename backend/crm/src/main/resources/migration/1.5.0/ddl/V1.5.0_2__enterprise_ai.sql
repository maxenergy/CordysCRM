-- set innodb lock wait timeout
SET SESSION innodb_lock_wait_timeout = 7200;

-- =====================================================
-- 企业工商信息表
-- =====================================================
CREATE TABLE enterprise_profile (
    `id`              VARCHAR(32)    NOT NULL COMMENT 'id',
    `customer_id`     VARCHAR(32)    NOT NULL COMMENT '客户ID',
    `iqicha_id`       VARCHAR(64)    DEFAULT NULL COMMENT '爱企查企业ID',
    `credit_code`     VARCHAR(64)    NOT NULL COMMENT '统一社会信用代码',
    `company_name`    VARCHAR(256)   NOT NULL COMMENT '企业名称',
    `legal_person`    VARCHAR(128)   DEFAULT NULL COMMENT '法定代表人',
    `reg_capital`     DECIMAL(18,2)  DEFAULT NULL COMMENT '注册资本(万元)',
    `reg_date`        DATE           DEFAULT NULL COMMENT '成立日期',
    `staff_size`      VARCHAR(64)    DEFAULT NULL COMMENT '人员规模',
    `industry_code`   VARCHAR(32)    DEFAULT NULL COMMENT '行业代码',
    `industry_name`   VARCHAR(128)   DEFAULT NULL COMMENT '行业名称',
    `province`        VARCHAR(64)    DEFAULT NULL COMMENT '省份',
    `city`            VARCHAR(64)    DEFAULT NULL COMMENT '城市',
    `address`         VARCHAR(512)   DEFAULT NULL COMMENT '注册地址',
    `status`          VARCHAR(64)    DEFAULT NULL COMMENT '经营状态',
    `phone`           VARCHAR(64)    DEFAULT NULL COMMENT '联系电话',
    `email`           VARCHAR(128)   DEFAULT NULL COMMENT '邮箱',
    `website`         VARCHAR(256)   DEFAULT NULL COMMENT '官网',
    `shareholders`    JSON           DEFAULT NULL COMMENT '股东信息',
    `executives`      JSON           DEFAULT NULL COMMENT '高管信息',
    `risks`           JSON           DEFAULT NULL COMMENT '风险信息',
    `source`          VARCHAR(32)    NOT NULL DEFAULT 'iqicha' COMMENT '数据来源',
    `last_sync_at`    BIGINT         DEFAULT NULL COMMENT '最后同步时间',
    `organization_id` VARCHAR(32)    NOT NULL COMMENT '组织ID',
    `create_time`     BIGINT         NOT NULL COMMENT '创建时间',
    `update_time`     BIGINT         NOT NULL COMMENT '更新时间',
    `create_user`     VARCHAR(32)    NOT NULL COMMENT '创建人',
    `update_user`     VARCHAR(32)    NOT NULL COMMENT '更新人',
    PRIMARY KEY (id),
    UNIQUE KEY uk_customer (customer_id),
    UNIQUE KEY uk_credit_org (credit_code, organization_id),
    KEY idx_iqicha (iqicha_id),
    KEY idx_name (company_name),
    KEY idx_organization (organization_id)
) COMMENT = '企业工商信息'
ENGINE = InnoDB
DEFAULT CHARSET = utf8mb4
COLLATE = utf8mb4_general_ci;

-- =====================================================
-- AI企业画像表
-- =====================================================
CREATE TABLE company_portrait (
    `id`              VARCHAR(32)    NOT NULL COMMENT 'id',
    `customer_id`     VARCHAR(32)    NOT NULL COMMENT '客户ID',
    `portrait`        JSON           NOT NULL COMMENT '画像数据',
    `opportunities`   JSON           DEFAULT NULL COMMENT '商机洞察',
    `risks`           JSON           DEFAULT NULL COMMENT '风险提示',
    `public_opinion`  JSON           DEFAULT NULL COMMENT '舆情信息',
    `model`           VARCHAR(64)    NOT NULL COMMENT 'AI模型名称',
    `version`         VARCHAR(32)    DEFAULT 'v1' COMMENT '画像版本',
    `source`          VARCHAR(32)    NOT NULL DEFAULT 'ai' COMMENT '数据来源',
    `generated_at`    BIGINT         NOT NULL COMMENT '生成时间',
    `organization_id` VARCHAR(32)    NOT NULL COMMENT '组织ID',
    `create_time`     BIGINT         NOT NULL COMMENT '创建时间',
    `update_time`     BIGINT         NOT NULL COMMENT '更新时间',
    `create_user`     VARCHAR(32)    NOT NULL COMMENT '创建人',
    `update_user`     VARCHAR(32)    NOT NULL COMMENT '更新人',
    PRIMARY KEY (id),
    UNIQUE KEY uk_cp_customer (customer_id),
    KEY idx_generated_at (generated_at),
    KEY idx_organization (organization_id)
) COMMENT = 'AI企业画像'
ENGINE = InnoDB
DEFAULT CHARSET = utf8mb4
COLLATE = utf8mb4_general_ci;

-- =====================================================
-- 话术模板表
-- =====================================================
CREATE TABLE call_script_template (
    `id`              VARCHAR(32)    NOT NULL COMMENT 'id',
    `name`            VARCHAR(128)   NOT NULL COMMENT '模板名称',
    `industry`        VARCHAR(64)    DEFAULT NULL COMMENT '适用行业',
    `scene`           VARCHAR(64)    NOT NULL COMMENT '场景(outreach/followup/renewal/meeting)',
    `channel`         VARCHAR(32)    DEFAULT 'phone' COMMENT '渠道(phone/wechat/email)',
    `language`        VARCHAR(16)    DEFAULT 'zh-CN' COMMENT '语言',
    `tone`            VARCHAR(32)    DEFAULT 'professional' COMMENT '语气(professional/enthusiastic/concise)',
    `content`         TEXT           NOT NULL COMMENT '模板内容',
    `variables`       JSON           DEFAULT NULL COMMENT '变量定义',
    `version`         VARCHAR(32)    DEFAULT 'v1' COMMENT '版本',
    `enabled`         BIT(1)         NOT NULL DEFAULT 1 COMMENT '是否启用',
    `organization_id` VARCHAR(32)    NOT NULL COMMENT '组织ID',
    `create_time`     BIGINT         NOT NULL COMMENT '创建时间',
    `update_time`     BIGINT         NOT NULL COMMENT '更新时间',
    `create_user`     VARCHAR(32)    NOT NULL COMMENT '创建人',
    `update_user`     VARCHAR(32)    NOT NULL COMMENT '更新人',
    PRIMARY KEY (id),
    KEY idx_template (industry, scene, channel, enabled),
    KEY idx_name (name),
    KEY idx_organization (organization_id)
) COMMENT = '话术模板'
ENGINE = InnoDB
DEFAULT CHARSET = utf8mb4
COLLATE = utf8mb4_general_ci;

-- =====================================================
-- 话术记录表
-- =====================================================
CREATE TABLE call_script (
    `id`              VARCHAR(32)    NOT NULL COMMENT 'id',
    `customer_id`     VARCHAR(32)    NOT NULL COMMENT '客户ID',
    `opportunity_id`  VARCHAR(32)    DEFAULT NULL COMMENT '商机ID',
    `template_id`     VARCHAR(32)    DEFAULT NULL COMMENT '模板ID',
    `scene`           VARCHAR(64)    NOT NULL COMMENT '场景',
    `channel`         VARCHAR(32)    DEFAULT 'phone' COMMENT '渠道',
    `language`        VARCHAR(16)    DEFAULT 'zh-CN' COMMENT '语言',
    `tone`            VARCHAR(32)    DEFAULT 'professional' COMMENT '语气',
    `tags`            JSON           DEFAULT NULL COMMENT '标签',
    `content`         TEXT           NOT NULL COMMENT '话术内容',
    `model`           VARCHAR(64)    DEFAULT NULL COMMENT 'AI模型名称',
    `generated_at`    BIGINT         DEFAULT NULL COMMENT '生成时间',
    `organization_id` VARCHAR(32)    NOT NULL COMMENT '组织ID',
    `create_time`     BIGINT         NOT NULL COMMENT '创建时间',
    `update_time`     BIGINT         NOT NULL COMMENT '更新时间',
    `create_user`     VARCHAR(32)    NOT NULL COMMENT '创建人',
    `update_user`     VARCHAR(32)    NOT NULL COMMENT '更新人',
    PRIMARY KEY (id),
    KEY idx_customer_scene (customer_id, scene),
    KEY idx_template (template_id),
    KEY idx_organization (organization_id)
) COMMENT = '话术记录'
ENGINE = InnoDB
DEFAULT CHARSET = utf8mb4
COLLATE = utf8mb4_general_ci;

-- =====================================================
-- 爱企查同步日志表
-- =====================================================
CREATE TABLE iqicha_sync_log (
    `id`              VARCHAR(32)    NOT NULL COMMENT 'id',
    `operator_id`     VARCHAR(32)    DEFAULT NULL COMMENT '操作人ID',
    `customer_id`     VARCHAR(32)    DEFAULT NULL COMMENT '客户ID',
    `iqicha_id`       VARCHAR(64)    DEFAULT NULL COMMENT '爱企查企业ID',
    `action`          VARCHAR(32)    NOT NULL COMMENT '操作类型(import/sync/update)',
    `request_params`  JSON           DEFAULT NULL COMMENT '请求参数',
    `response_code`   INT            DEFAULT NULL COMMENT '响应码',
    `response_msg`    VARCHAR(256)   DEFAULT NULL COMMENT '响应消息',
    `diff_snapshot`   JSON           DEFAULT NULL COMMENT '数据变更快照',
    `cost`            DECIMAL(10,2)  DEFAULT NULL COMMENT '费用',
    `organization_id` VARCHAR(32)    NOT NULL COMMENT '组织ID',
    `create_time`     BIGINT         NOT NULL COMMENT '创建时间',
    PRIMARY KEY (id),
    KEY idx_customer_action (customer_id, action),
    KEY idx_iqicha (iqicha_id),
    KEY idx_created (create_time),
    KEY idx_organization (organization_id)
) COMMENT = '爱企查同步日志'
ENGINE = InnoDB
DEFAULT CHARSET = utf8mb4
COLLATE = utf8mb4_general_ci;

-- =====================================================
-- AI生成日志表
-- =====================================================
CREATE TABLE ai_generation_log (
    `id`                VARCHAR(32)    NOT NULL COMMENT 'id',
    `customer_id`       VARCHAR(32)    DEFAULT NULL COMMENT '客户ID',
    `scene`             VARCHAR(32)    NOT NULL COMMENT '场景(portrait/script)',
    `model`             VARCHAR(64)    NOT NULL COMMENT 'AI模型名称',
    `provider`          VARCHAR(32)    NOT NULL COMMENT '提供商(openai/claude/local)',
    `prompt_hash`       CHAR(64)       DEFAULT NULL COMMENT 'Prompt哈希',
    `tokens_prompt`     INT            DEFAULT NULL COMMENT 'Prompt Token数',
    `tokens_completion` INT            DEFAULT NULL COMMENT '完成 Token数',
    `latency_ms`        INT            DEFAULT NULL COMMENT '耗时(毫秒)',
    `status`            VARCHAR(16)    NOT NULL COMMENT '状态(success/failed/timeout)',
    `error_msg`         VARCHAR(256)   DEFAULT NULL COMMENT '错误信息',
    `cost`              DECIMAL(10,4)  DEFAULT NULL COMMENT '费用',
    `organization_id`   VARCHAR(32)    NOT NULL COMMENT '组织ID',
    `create_time`       BIGINT         NOT NULL COMMENT '创建时间',
    `create_user`       VARCHAR(32)    NOT NULL COMMENT '创建人',
    PRIMARY KEY (id),
    KEY idx_customer_scene (customer_id, scene),
    KEY idx_status (status),
    KEY idx_created (create_time),
    KEY idx_organization (organization_id)
) COMMENT = 'AI生成日志'
ENGINE = InnoDB
DEFAULT CHARSET = utf8mb4
COLLATE = utf8mb4_general_ci;

-- =====================================================
-- 集成配置表
-- =====================================================
CREATE TABLE integration_config (
    `id`              VARCHAR(32)    NOT NULL COMMENT 'id',
    `config_key`      VARCHAR(64)    NOT NULL COMMENT '配置键',
    `config_value`    TEXT           NOT NULL COMMENT '配置值',
    `encrypted`       BIT(1)         NOT NULL DEFAULT 0 COMMENT '是否加密',
    `organization_id` VARCHAR(32)    NOT NULL COMMENT '组织ID',
    `description`     VARCHAR(256)   DEFAULT NULL COMMENT '描述',
    `create_time`     BIGINT         NOT NULL COMMENT '创建时间',
    `update_time`     BIGINT         NOT NULL COMMENT '更新时间',
    `create_user`     VARCHAR(32)    NOT NULL COMMENT '创建人',
    `update_user`     VARCHAR(32)    NOT NULL COMMENT '更新人',
    PRIMARY KEY (id),
    UNIQUE KEY uk_key_org (config_key, organization_id)
) COMMENT = '集成配置'
ENGINE = InnoDB
DEFAULT CHARSET = utf8mb4
COLLATE = utf8mb4_general_ci;

-- set innodb lock wait timeout to default
SET SESSION innodb_lock_wait_timeout = DEFAULT;
