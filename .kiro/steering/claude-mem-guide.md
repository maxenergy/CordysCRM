# Claude-Mem 使用指南

## 概述

Claude-Mem 是 Kiro IDE 的持久化记忆系统，通过自动捕获工具使用、生成语义摘要，并在未来会话中提供这些信息，实现跨会话的上下文连续性。

## 核心功能

### 自动记忆捕获
- **会话开始** - 自动注入最近的观察作为上下文
- **用户提示** - 记录每个提交的提示词
- **工具执行** - 捕获所有工具使用（文件读取、搜索、bash 命令等）
- **会话结束** - 生成全面的会话摘要

### 自然语言查询
使用自然语言搜索项目历史和过往会话：

**最近工作：**
- "上次会话我们做了什么？"
- "显示这个项目的最近工作"
- "本周我们在做什么？"

**实现细节：**
- "我们是如何实现身份验证的？"
- "错误处理是在哪里添加的？"
- "数据库架构采用了什么方法？"

**文件变更：**
- "worker-service.ts 做了哪些修改？"
- "API 端点是什么时候修改的？"
- "显示配置文件的变更历史"

**问题解决：**
- "我们是如何修复内存泄漏的？"
- "CORS 问题的解决方案是什么？"
- "为什么选择这个架构？"

**决策和上下文：**
- "关于 API 设计我们做了哪些决策？"
- "我们讨论了哪些权衡？"
- "数据库遇到了什么问题？"

## 渐进式披露记忆模型

Claude-Mem 使用渐进式披露方法高效管理上下文：

### 1. 索引层（轻量级）
- 查看存在哪些观察
- 查看元数据（时间戳、文件名、工具类型）
- 在获取详情前检查 token 成本
- 快速扫描可用内容

### 2. 详情层（按需加载）
- 需要时获取完整叙述
- 获取工具使用的压缩摘要
- 访问变更的语义描述
- 只加载需要的内容

### 3. 完美回忆层（源真相）
- 访问原始源代码
- 查看完整转录
- 查看确切的工具输入和输出
- 需要时提供完全保真度

## 搜索操作

### 按概念搜索
搜索与特定概念或主题相关的观察：
- "身份验证实现"
- "错误处理模式"
- "数据库迁移"

### 按文件搜索
查找与特定文件相关的所有观察：
- "src/services/worker-service.ts"
- "package.json"
- ".kiro/settings/"

### 按类型搜索
按工具类型过滤观察：
- 文件读取
- 文件写入
- Bash 命令
- 搜索操作

### 时间线
按时间顺序查看观察：
- 最近 24 小时
- 上周
- 特定日期范围
- 按会话

### 会话
浏览完整会话：
- 查看会话摘要
- 查看会话中的所有观察
- 理解工作流程

## 使用场景

### 开始编码任务前
```
1. 使用自然语言查询搜索相关经验
2. 查看过往类似任务的实现方式
3. 了解之前遇到的问题和解决方案
```

### 完成复杂任务后
```
1. 让会话自然完成以生成良好的摘要
2. 摘要会自动保存并可在未来搜索
```

### 跨会话工作
```
1. 新会话开始时自动注入相关上下文
2. 查询"上次我们做了什么"快速恢复工作
3. 搜索特定文件或功能的历史
```

## 配置

设置在 `.kiro/settings/claude-mem.json` 中管理：

```json
{
  "CLAUDE_MEM_MODEL": "claude-sonnet-4-5",
  "CLAUDE_MEM_WORKER_PORT": "37777",
  "CLAUDE_MEM_WORKER_HOST": "127.0.0.1",
  "CLAUDE_MEM_CONTEXT_OBSERVATIONS": "50",
  "CLAUDE_MEM_LOG_LEVEL": "INFO",
  "KIRO_HOOKS_ENABLED": "true"
}
```

### 配置选项

- **CLAUDE_MEM_MODEL**: 用于生成观察和摘要的 AI 模型
  - 默认: `claude-sonnet-4-5`
  
- **CLAUDE_MEM_WORKER_PORT**: Worker 服务端口
  - 默认: `37777`
  
- **CLAUDE_MEM_CONTEXT_OBSERVATIONS**: 会话开始时注入的观察数量
  - 默认: `50`
  - 增加以获得更多上下文，减少以节省 token
  
- **CLAUDE_MEM_LOG_LEVEL**: 日志详细程度
  - 选项: `DEBUG`, `INFO`, `WARN`, `ERROR`, `SILENT`
  - 默认: `INFO`
  
- **KIRO_HOOKS_ENABLED**: 启用/禁用 Kiro hooks
  - 默认: `true`

## Worker 服务

Worker 服务是处理所有记忆操作的后台 HTTP 服务器。它独立于 Kiro IDE 运行，并在会话之间持久化。

### 服务管理

```bash
# 启动 worker 服务
bun plugin/scripts/worker-cli.js start

# 停止 worker 服务
bun plugin/scripts/worker-cli.js stop

# 重启 worker 服务
bun plugin/scripts/worker-cli.js restart

# 检查 worker 状态
bun plugin/scripts/worker-cli.js status
```

### Web 查看器

访问记忆流查看器：http://localhost:37777

Web 查看器提供：
- 实时观察捕获流
- 会话摘要和统计
- 搜索界面
- 配置设置
- 工作的可视化时间线

## 隐私和安全

### 私有标签

使用 `<private>` 标签排除敏感内容：

```
<private>
API_KEY=sk-1234567890abcdef
DATABASE_PASSWORD=secret-password
AWS_SECRET_KEY=AKIAIOSFODNN7EXAMPLE
</private>
```

`<private>` 标签内的内容：
- 在存储前被剥离
- 永远不会发送到 AI 模型
- 不包含在观察中
- 不可搜索

### 数据位置

所有数据本地存储在 `~/.claude-mem/`：
- `claude-mem.db` - 包含观察和会话的 SQLite 数据库
- `chroma/` - 用于语义搜索的向量嵌入
- `logs/` - Worker 服务日志

## 故障排除

### 上下文未出现

如果观察未在会话开始时注入：

1. **检查 worker 状态：**
   ```bash
   bun plugin/scripts/worker-cli.js status
   ```

2. **重启 worker：**
   ```bash
   bun plugin/scripts/worker-cli.js restart
   ```

3. **检查日志：**
   ```bash
   tail -f ~/.claude-mem/logs/worker-$(date +%Y-%m-%d).log
   ```

### 观察未被捕获

如果工具使用未被记录：

1. **验证 hooks 已安装：**
   ```bash
   ls -la .kiro/hooks/
   ```

2. **测试 worker 连接：**
   ```bash
   curl http://localhost:37777/api/readiness
   ```

## 最佳实践

### 有效使用记忆

1. **使用描述性提示**：清晰的提示创建更好的观察
2. **标记敏感数据**：始终对机密使用 `<private>` 标签
3. **定期摘要**：让会话自然完成以获得良好的摘要
4. **有意义的查询**：提出具体问题以获得更好的搜索结果

### 工作区组织

1. **每个项目一个工作区**：每个工作区有自己的记忆
2. **一致的命名**：使用清晰的文件和目录名称
3. **逻辑结构**：以对记忆有意义的方式组织代码

## 详细文档

完整文档请参考：`.kiro/steering/claude-mem.md`

## 资源

- **文档**: https://docs.claude-mem.ai
- **GitHub**: https://github.com/thedotmack/claude-mem
- **问题**: https://github.com/thedotmack/claude-mem/issues
