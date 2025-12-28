# 如何查询项目开发进度

## Claude-Mem 服务状态

Claude-Mem Worker 服务已启动并运行在 `http://127.0.0.1:37777`

## 快速查询方法

### 1. 查询最近的工作

在新会话中，直接询问：

```
上次会话我们做了什么？
```

或者：

```
显示这个项目的最近工作
```

### 2. 查询特定功能的实现

```
我们是如何实现企业搜索的？
```

```
AI 成本配置功能是怎么实现的？
```

### 3. 查询文件变更历史

```
EnterpriseController.java 做了哪些修改？
```

```
显示 AI 相关文件的变更历史
```

### 4. 查询问题解决方案

```
我们是如何修复企业搜索超时的？
```

```
统一社会信用代码去重是怎么解决的？
```

### 5. 查询设计决策

```
关于 AI 成本配置我们做了哪些决策？
```

```
企业数据完整性方案是如何设计的？
```

## 当前项目开发状态

### 已完成的 Spec

1. **AI 成本配置 (ai-cost-configuration)** ✅
   - 状态：已完成
   - 位置：`.kiro/specs/ai-cost-configuration/`
   - 功能：AI 模型定价配置、成本统计

2. **企业搜索分页 (enterprise-search-pagination)** ✅
   - 状态：已完成
   - 位置：`.kiro/specs/enterprise-search-pagination/`
   - 功能：企业搜索结果分页、SQL 优化

3. **核心数据完整性 (core-data-integrity)** ✅
   - 状态：已完成
   - 位置：`.kiro/specs/core-data-integrity/`
   - 功能：统一社会信用代码规范化、去重

4. **Chrome 扩展弹性抓取 (extension-resilient-scraping)** ✅
   - 状态：已完成
   - 位置：`.kiro/specs/extension-resilient-scraping/`
   - 功能：多策略 DOM 选择器、错误处理

### 进行中的 Spec

5. **CRM 移动端企业 AI (crm-mobile-enterprise-ai)** 🚧
   - 状态：进行中
   - 位置：`.kiro/specs/crm-mobile-enterprise-ai/`
   - 进度：
     - [x] 1. 企业搜索基础功能
     - [x] 2. AI 画像功能
     - [x] 3. AI 话术功能
     - [ ] 4. 移动端集成（待开始）

## 使用 Claude-Mem 工具查询

### 搜索相关经验

```
使用 mcp_claude_mem_search 工具
参数：{"query": "企业搜索实现"}
```

### 查看最近上下文

```
使用 mcp_claude_mem_get_recent_context 工具
参数：{"limit": 10}
```

### 查看时间线

```
使用 mcp_claude_mem_timeline 工具
参数：{"query": "AI 成本配置", "limit": 20}
```

## 项目文档位置

- **开发状态**: `memory-bank/development-status.md`
- **Spec 总结**: `.kiro/specs/SPEC_CREATION_SUMMARY.md`
- **任务列表**: `.kiro/specs/*/tasks.md`
- **设计文档**: `.kiro/specs/*/design.md`
- **需求文档**: `.kiro/specs/*/requirements.md`

## 重启 Claude-Mem 服务

如果需要重启服务：

```bash
# 检查服务状态
curl http://127.0.0.1:37777/api/readiness

# 查看 worker 进程
ps aux | grep -i "worker-service"

# 如果需要重启，找到进程 ID 并重启
kill <PID>
# 服务会自动重启
```

## 注意事项

1. **自动记忆捕获**：所有工具使用（文件读取、搜索、命令等）都会自动记录
2. **会话摘要**：每次会话结束时自动生成摘要
3. **自然语言搜索**：支持中文和英文自然语言查询
4. **上下文注入**：新会话开始时自动注入最近 50 条相关观察

## 示例查询

### 查询整体进度

```
本项目目前完成了哪些功能？还有哪些待开发？
```

### 查询特定模块

```
企业搜索模块的实现细节是什么？
```

### 查询技术决策

```
为什么选择使用 MyBatis 的 XML Mapper？
```

### 查询问题排查

```
之前遇到的企业搜索超时问题是如何解决的？
```

## Web 查看器

访问 http://localhost:37777 可以查看：
- 实时观察捕获流
- 会话摘要和统计
- 搜索界面
- 配置设置
- 工作的可视化时间线
