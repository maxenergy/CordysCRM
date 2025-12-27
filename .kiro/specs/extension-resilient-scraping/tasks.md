# Implementation Plan: Extension Resilient Scraping

## Overview

本实现计划将 Chrome Extension 的数据采集系统从硬编码选择器重构为配置化、多策略、可监控的韧性系统。任务分为三个阶段：核心重构、远程配置、监控和优化。

## Tasks

### Phase 1: 核心重构（当前 Sprint）

- [ ] 1. 定义配置数据结构
  - [ ] 1.1 创建 TypeScript 接口定义
    - 定义 `ExtractionConfig`、`PlatformConfig`、`FieldConfig` 接口
    - 定义 `Strategy` 联合类型（css, json-ld, regex, meta, xpath）
    - 定义 `Transform` 联合类型（regex, replace, trim）
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

  - [ ] 1.2 创建 JSON Schema 验证
    - 使用 Ajv 库实现 JSON Schema 验证
    - 定义配置文件的 JSON Schema
    - _Requirements: 10.5_

  - [ ]* 1.3 编写配置验证测试
    - 测试有效配置通过验证
    - 测试无效配置被拒绝
    - _Requirements: 1.1, 10.5_

- [ ] 2. 实现内置默认配置
  - [ ] 2.1 创建 `default-config.ts`
    - 将当前 `extractor.ts` 的 SELECTORS 转换为新配置格式
    - 支持爱企查和企查查两个平台
    - 为每个字段配置多个备选策略
    - _Requirements: 1.5_

  - [ ] 2.2 添加配置文档注释
    - 为每个策略添加说明注释
    - 记录策略的稳定性评级
    - _Requirements: 1.1_

- [ ] 3. Checkpoint A - 验证配置结构
  - 确保配置格式清晰易懂
  - 代码审查
  - 询问用户是否有问题

- [ ] 4. 实现策略执行器
  - [ ] 4.1 创建 `CssStrategyExecutor`
    - 实现 CSS 选择器提取
    - 支持属性提取（attribute）
    - 支持 Transform 应用
    - _Requirements: 2.1, 3.4_

  - [ ] 4.2 创建 `JsonLdStrategyExecutor`
    - 查找并解析 `<script type="application/ld+json">`
    - 实现简单的 JSONPath 提取（支持 $.field.nested）
    - 支持 Transform 应用
    - _Requirements: 2.2_

  - [ ] 4.3 创建 `RegexStrategyExecutor`
    - 在页面文本中执行正则匹配
    - 支持捕获组提取
    - _Requirements: 2.3_

  - [ ] 4.4 创建 `MetaStrategyExecutor`
    - 提取 `<meta>` 标签内容
    - 支持 `document.title` 提取
    - 支持 Transform 应用
    - _Requirements: 2.4_

  - [ ] 4.5 创建 `XPathStrategyExecutor`
    - 使用 `document.evaluate` 执行 XPath
    - 支持属性提取
    - 支持 Transform 应用
    - _Requirements: 2.5_

  - [ ]* 4.6 编写策略执行器单元测试
    - 为每个执行器编写测试
    - 测试边界条件（元素不存在、格式错误等）
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

- [ ] 5. 实现 Transform 管道
  - [ ] 5.1 创建 `TransformPipeline` 类
    - 实现 `regex` transform
    - 实现 `replace` transform
    - 实现 `trim` transform
    - _Requirements: 3.1, 3.2, 3.3_

  - [ ]* 5.2 编写 Transform 属性测试
    - **Property 4: Transform 幂等性**
    - 测试各种输入组合
    - _Requirements: 3.1, 3.2, 3.3_

- [ ] 6. Checkpoint B - 验证策略执行器
  - 确保所有测试通过
  - 手动测试各种策略
  - 询问用户是否有问题

- [ ] 7. 实现 ExtractorEngine
  - [ ] 7.1 创建 `ExtractorEngine` 类
    - 实现 `extractAll()` 方法
    - 实现 `extractField()` 方法
    - 实现 `executeStrategy()` 方法
    - 记录 Hit_Index
    - _Requirements: 2.6, 2.7_

  - [ ] 7.2 实现平台检测逻辑
    - 根据 URL 匹配 `hostPattern`
    - 返回对应的平台配置
    - _Requirements: 1.2_

  - [ ] 7.3 实现数据清洗和验证
    - HTML 转义提取的数据
    - 限制字段长度（1000 字符）
    - _Requirements: 10.3, 10.4_

  - [ ]* 7.4 编写 ExtractorEngine 单元测试
    - 测试完整提取流程
    - 测试策略降级逻辑
    - **Property 2: 策略顺序执行**
    - **Property 3: Hit Index 准确性**
    - _Requirements: 2.6, 2.7_

- [ ] 8. 重构现有 extractor.ts
  - [ ] 8.1 替换硬编码选择器
    - 使用 `ExtractorEngine` 替换现有逻辑
    - 保持对外接口不变（`extractEnterpriseData()`）
    - _Requirements: 1.1_

  - [ ] 8.2 更新错误处理
    - 使用新的错误分类
    - 记录提取失败的字段
    - _Requirements: 8.1, 8.2_

  - [ ]* 8.3 编写回归测试
    - 确保重构后功能不变
    - 使用真实页面 HTML 快照测试
    - _Requirements: 1.1_

- [ ] 9. Checkpoint C - 验证核心重构
  - 运行所有测试
  - 在测试环境手动验证
  - 询问用户是否有问题

### Phase 2: 远程配置

- [ ] 10. 实现 ConfigManager (Extension)
  - [ ] 10.1 创建 `ConfigManager` 类
    - 实现 `getConfig()` 方法（优先使用缓存）
    - 实现 `fetchRemoteConfig()` 方法
    - 实现 `isConfigStale()` 方法
    - 实现 `getDefaultConfig()` 方法
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

  - [ ] 10.2 实现配置缓存逻辑
    - 使用 `chrome.storage.local` 缓存配置
    - 检查时间戳判断是否过期（1 小时）
    - 异步更新过期配置
    - _Requirements: 4.2, 4.3, 4.4_

  - [ ]* 10.3 编写 ConfigManager 单元测试
    - 测试缓存命中逻辑
    - 测试降级到默认配置
    - **Property 1: 配置降级安全性**
    - **Property 6: 配置缓存一致性**
    - _Requirements: 1.5, 4.3, 4.4_

- [ ] 11. 实现后端配置管理 API
  - [ ] 11.1 创建 `ExtractionConfig` 实体类
    - 定义数据库表结构
    - 添加版本号、时间戳、创建者字段
    - _Requirements: 9.1, 9.2_

  - [ ] 11.2 创建 `ExtractionConfigController`
    - 实现 `GET /api/config/extraction` 端点
    - 实现 `POST /api/config/extraction` 端点（管理员）
    - 实现 `GET /api/config/extraction/history` 端点
    - _Requirements: 4.1, 9.4_

  - [ ] 11.3 实现配置版本管理
    - 每次更新创建新版本
    - 记录变更日志
    - 支持回滚到历史版本
    - _Requirements: 9.1, 9.2, 9.3, 9.5_

  - [ ]* 11.4 编写配置管理 API 测试
    - 测试配置的 CRUD 操作
    - 测试版本管理逻辑
    - 测试权限控制
    - _Requirements: 4.1, 9.1, 9.3_

- [ ] 12. Checkpoint D - 验证远程配置
  - 确保所有测试通过
  - 手动测试配置更新流程
  - 询问用户是否有问题

- [ ] 13. 集成 ConfigManager 到 ExtractorEngine
  - [ ] 13.1 更新 `extractor.ts` 初始化逻辑
    - 在提取前加载配置
    - 使用加载的配置创建 `ExtractorEngine`
    - _Requirements: 4.2_

  - [ ] 13.2 添加配置加载失败处理
    - 显示友好的错误提示
    - 降级到内置配置
    - _Requirements: 1.5, 4.4_

  - [ ]* 13.3 编写集成测试
    - 测试完整的配置加载和提取流程
    - 测试配置更新后的行为
    - _Requirements: 4.1, 4.2, 4.3_

### Phase 3: 监控和优化

- [ ] 14. 实现提取反馈机制
  - [ ] 14.1 扩展导入 API 接收 Hit_Index
    - 修改 `EnterpriseImportRequest` 添加 `hitIndexes` 字段
    - 修改 `EnterpriseController` 接收并记录 Hit_Index
    - _Requirements: 5.1, 5.2_

  - [ ] 14.2 创建 `ExtractionLog` 实体类
    - 记录平台、字段、策略索引、时间戳
    - 添加数据库索引优化查询
    - _Requirements: 5.2_

  - [ ] 14.3 实现 `ExtractionStatisticsService`
    - 实现 `recordExtraction()` 方法
    - 实现 `getStrategyStats()` 方法
    - 实现 `checkAndAlert()` 方法
    - _Requirements: 5.3, 5.4_

  - [ ]* 14.4 编写统计服务测试
    - 测试命中率计算
    - **Property 8: 策略命中率统计准确性**
    - 测试告警触发逻辑
    - _Requirements: 5.3, 5.4_

- [ ] 15. 实现告警系统
  - [ ] 15.1 创建 `AlertService`
    - 支持 Slack Webhook 告警
    - 支持钉钉 Webhook 告警
    - 支持邮件告警
    - _Requirements: 5.4_

  - [ ] 15.2 配置告警规则
    - 高优先级策略（index 0-1）命中率低于 50% 触发告警
    - 必填字段提取失败率超过 10% 触发告警
    - _Requirements: 5.4_

  - [ ]* 15.3 编写告警服务测试
    - 测试各种告警渠道
    - 测试告警触发条件
    - _Requirements: 5.4_

- [ ] 16. Checkpoint E - 验证监控系统
  - 确保所有测试通过
  - 手动触发告警验证
  - 询问用户是否有问题

- [ ] 17. 实现 Canary 自动化测试
  - [ ] 17.1 创建 Playwright 测试脚本
    - 编写 `scripts/canary-test.ts`
    - 定义样本企业列表（至少 3 个）
    - 实现提取和验证逻辑
    - _Requirements: 6.1, 6.3_

  - [ ] 17.2 配置 CI/CD 定时任务
    - 创建 GitHub Actions workflow
    - 配置每日凌晨 2 点执行
    - 配置 Cookie 环境变量
    - _Requirements: 6.2, 6.5_

  - [ ] 17.3 集成告警通知
    - 测试失败时发送 Slack/钉钉通知
    - 附带截图和错误信息
    - _Requirements: 6.4_

  - [ ]* 17.4 编写 Canary 测试用例
    - 至少覆盖 3 个样本企业
    - 验证所有必填字段
    - _Requirements: 6.3_

- [ ] 18. 实现手动模式 UI
  - [ ] 18.1 创建 Manual Mode Popup 界面
    - 设计表单布局
    - 预填已提取的字段
    - 高亮显示缺失的必填字段
    - _Requirements: 7.1, 7.2, 7.3_

  - [ ] 18.2 实现手动输入逻辑
    - 允许用户编辑所有字段
    - 验证必填字段
    - 提交到后端
    - _Requirements: 7.4_

  - [ ] 18.3 添加友好提示
    - 显示提取成功率（如 "8/10 字段成功"）
    - 列出提取失败的字段
    - 提供"重试"和"报告问题"按钮
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

  - [ ]* 18.4 编写 UI 测试
    - 测试表单渲染
    - 测试数据提交
    - **Property 5: Required Field 验证**
    - _Requirements: 7.1, 7.2, 7.3, 7.4_

- [ ] 19. 实现问题反馈机制
  - [ ] 19.1 创建反馈 API
    - 实现 `POST /api/extraction/feedback` 端点
    - 记录用户反馈和页面快照
    - _Requirements: 8.5_

  - [ ] 19.2 添加"报告问题"功能
    - 在 Popup 中添加按钮
    - 收集提取结果、页面 URL、用户备注
    - 发送到后端
    - _Requirements: 8.5_

- [ ] 20. Checkpoint F - 验证完整系统
  - 运行所有测试（单元测试 + 属性测试 + 集成测试 + Canary 测试）
  - 在测试环境进行完整回归测试
  - 更新文档和开发状态报告
  - 询问用户是否有问题

- [ ]* 21. 性能优化
  - [ ]* 21.1 优化配置加载性能
    - 使用 Service Worker 缓存配置
    - 减少不必要的网络请求
    - _Requirements: 4.2_

  - [ ]* 21.2 优化提取性能
    - 避免重复的 DOM 查询
    - 使用 `requestIdleCallback` 延迟非关键提取
    - _Requirements: 2.1_

  - [ ]* 21.3 性能测试
    - 测试配置加载时间
    - 测试提取执行时间
    - 确保不影响页面性能

- [ ]* 22. 文档和培训
  - [ ]* 22.1 编写配置文件编写指南
    - 说明各种策略的使用场景
    - 提供最佳实践建议
    - _Requirements: 1.1, 2.1, 2.2, 2.3, 2.4, 2.5_

  - [ ]* 22.2 编写运维手册
    - 说明如何更新配置
    - 说明如何监控提取成功率
    - 说明如何处理告警
    - _Requirements: 4.1, 5.3, 6.4_

  - [ ]* 22.3 编写用户帮助文档
    - 说明手动模式的使用
    - 说明如何报告问题
    - _Requirements: 7.1, 8.5_

## Notes

- 任务标记 `*` 的为可选任务（主要是测试和文档相关），可以跳过以加快 MVP 开发
- 每个 Checkpoint 都需要确保所有测试通过并征求用户反馈
- Phase 1（核心重构）是基础，必须优先完成
- Phase 2（远程配置）和 Phase 3（监控）可以根据优先级调整顺序
- Canary 测试需要配置 Cookie 环境变量，注意安全性
- 属性测试应配置为至少运行 100 次迭代
- 每个属性测试必须在注释中标记其验证的设计属性编号
