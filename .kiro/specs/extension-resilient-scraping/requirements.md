# Requirements Document: Extension Resilient Scraping

## Introduction

本规格文档旨在解决 CordysCRM Chrome Extension 数据采集脆弱性问题（P0 级别）。当前实现依赖硬编码的 CSS 选择器，当第三方网站（爱企查/企查查）更新页面结构时，数据采集功能会立即失效，导致核心业务中断。

本方案通过配置化选择器、多策略提取、自动化监控和降级处理，构建一个韧性强、易维护的数据采集系统。

## Glossary

- **System**: CordysCRM Chrome Extension
- **Extractor**: 数据提取器，负责从网页中提取企业信息
- **Strategy**: 提取策略，如 CSS 选择器、XPath、JSON-LD、正则表达式
- **Config**: 提取配置文件，定义字段和提取策略
- **Canary_Test**: 金丝雀测试，自动化监测页面结构变化
- **Manual_Mode**: 手动模式，当自动提取失败时由用户手动补充数据
- **Required_Field**: 必填字段，如企业名称、信用代码
- **Optional_Field**: 可选字段，如注册资本、行业
- **Hit_Index**: 命中索引，记录哪个策略成功提取了数据
- **Fallback**: 降级策略，当主要策略失败时的备选方案
- **Transform**: 数据转换，对提取的原始数据进行清洗和格式化

## Requirements

### Requirement 1: 配置化提取规则

**User Story:** 作为开发者，我希望提取规则存储在配置文件中，而不是硬编码在代码里，以便快速响应页面结构变化。

#### Acceptance Criteria

1. THE System SHALL 支持从 JSON 配置文件加载提取规则
2. THE Config SHALL 定义多个平台（如 aiqicha、qichacha）的提取规则
3. THE Config SHALL 为每个字段定义是否为 Required_Field
4. THE Config SHALL 支持版本号和时间戳字段
5. WHEN Config 格式错误时，THE System SHALL 降级使用内置默认配置

### Requirement 2: 多策略提取

**User Story:** 作为开发者，我希望系统支持多种提取策略，以应对不同的页面结构和数据格式。

#### Acceptance Criteria

1. THE System SHALL 支持 CSS 选择器策略（css）
2. THE System SHALL 支持 JSON-LD 结构化数据策略（json-ld）
3. THE System SHALL 支持正则表达式策略（regex）
4. THE System SHALL 支持 Meta 标签策略（meta）
5. THE System SHALL 支持 XPath 策略（xpath）
6. WHEN 一个策略失败时，THE System SHALL 自动尝试下一个策略
7. THE System SHALL 记录成功策略的 Hit_Index

### Requirement 3: 数据转换和清洗

**User Story:** 作为开发者，我希望系统能够自动清洗提取的数据，去除多余的标签和空白字符。

#### Acceptance Criteria

1. THE System SHALL 支持正则表达式提取（regex transform）
2. THE System SHALL 支持字符串替换（replace transform）
3. THE System SHALL 支持 Trim 操作（trim transform）
4. THE System SHALL 支持提取 HTML 属性（attribute extraction）
5. WHEN Transform 失败时，THE System SHALL 返回原始提取值

### Requirement 4: 远程配置更新

**User Story:** 作为运维人员，我希望能够远程更新提取配置，而不需要发布新版本的 Extension。

#### Acceptance Criteria

1. THE System SHALL 提供 API 端点 `GET /api/config/extraction` 返回最新配置
2. THE Extension SHALL 在启动时检查本地配置的时间戳
3. WHEN 本地配置超过 1 小时时，THE Extension SHALL 异步请求新配置
4. WHEN 请求失败时，THE Extension SHALL 静默使用旧配置
5. THE Extension SHALL 将配置缓存在 `chrome.storage.local` 中

### Requirement 5: 提取成功率监控

**User Story:** 作为开发者，我希望系统能够记录每个策略的成功率，以便及时发现页面结构变化。

#### Acceptance Criteria

1. THE Extension SHALL 在成功提取时记录 Hit_Index
2. THE Extension SHALL 将 Hit_Index 随导入数据一起发送到后端
3. THE Backend SHALL 统计每个策略的命中率
4. WHEN 高优先级策略的命中率从 90% 降到 50% 时，THE System SHALL 发送告警
5. THE Backend SHALL 提供 API 查询策略命中率统计

### Requirement 6: Canary 自动化测试

**User Story:** 作为 QA 工程师，我希望系统能够自动监测页面结构变化，在用户发现问题前提前告警。

#### Acceptance Criteria

1. THE System SHALL 使用 Playwright 实现 Canary 测试脚本
2. THE Canary_Test SHALL 每日自动执行（如凌晨 2 点）
3. THE Canary_Test SHALL 测试至少 3 个样本企业页面
4. WHEN 提取失败时，THE System SHALL 发送告警到 Slack/钉钉
5. THE Canary_Test SHALL 支持使用预存的 Cookie 绕过登录

### Requirement 7: 降级到手动模式

**User Story:** 作为用户，我希望当自动提取失败时，系统能够让我手动补充数据，而不是完全无法使用。

#### Acceptance Criteria

1. WHEN Required_Field 提取失败时，THE Extension SHALL 打开 Popup 进入 Manual_Mode
2. THE Manual_Mode SHALL 预填已成功提取的字段
3. THE Manual_Mode SHALL 高亮显示缺失的 Required_Field
4. THE Manual_Mode SHALL 允许用户手动输入或粘贴数据
5. WHEN Optional_Field 提取失败时，THE Extension SHALL 显示警告图标但允许导入

### Requirement 8: 提取失败友好提示

**User Story:** 作为用户，我希望系统能够清楚地告诉我哪些字段提取失败了，以及如何解决。

#### Acceptance Criteria

1. THE Extension SHALL 显示提取成功的字段数量（如 "8/10 字段成功"）
2. THE Extension SHALL 列出提取失败的字段名称
3. THE Extension SHALL 提供"重试"按钮重新执行提取
4. THE Extension SHALL 提供"手动模式"按钮切换到 Manual_Mode
5. THE Extension SHALL 提供"报告问题"按钮发送反馈到后端

### Requirement 9: 配置版本管理

**User Story:** 作为开发者，我希望能够管理多个配置版本，以便快速回滚到稳定版本。

#### Acceptance Criteria

1. THE Backend SHALL 为每个配置分配唯一的版本号
2. THE Backend SHALL 记录配置的创建时间和创建者
3. THE Backend SHALL 支持回滚到历史版本
4. THE Backend SHALL 提供 API 查询配置历史
5. THE Backend SHALL 在配置更新时记录变更日志

### Requirement 10: 安全性保障

**User Story:** 作为安全工程师，我希望配置文件不能包含可执行代码，防止代码注入攻击。

#### Acceptance Criteria

1. THE Config SHALL 仅包含声明式规则（选择器、正则、预定义函数）
2. THE System SHALL 禁止在配置中使用 `eval()` 或 `Function()` 构造器
3. THE System SHALL 对提取的数据进行 HTML 转义
4. THE System SHALL 限制提取字段的最大长度（如 1000 字符）
5. THE Backend SHALL 对配置文件进行 JSON Schema 验证
