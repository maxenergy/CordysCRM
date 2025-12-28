# Claude-Mem 故障排除指南

## 问题：搜索历史不成功，没有观察记录

### 诊断结果

运行 `./scripts/diagnose_claude_mem.sh` 发现：

1. ✓ Worker 服务运行正常
2. ✗ **数据库中没有观察记录 (0 条)**
3. ✓ Hooks 已安装 (6 个文件)
4. ✗ **Chroma 向量数据库不存在**
5. ✓ 配置文件正确

### 根本原因

**Kiro IDE 的 hooks 系统没有触发观察捕获**

Claude-Mem 依赖 Kiro IDE 的 hooks 系统来捕获：
- 用户提示 (user-prompt-hook.js)
- 工具使用 (tool-use-hook.js)
- 会话开始/结束 (session-start-hook.js, session-end-hook.js)

如果 hooks 没有触发，就不会有任何观察记录被捕获。

### 修复步骤

#### 步骤 1: 重启 Worker 服务

```bash
./scripts/restart_claude_mem.sh
```

#### 步骤 2: 重新加载 Kiro IDE 窗口

**这是最关键的一步！**

在 Kiro IDE 中：
1. 按 `Ctrl+Shift+P` (或 `Cmd+Shift+P` on Mac)
2. 输入 "Reload Window"
3. 选择 "Developer: Reload Window"

或者直接重启 Kiro IDE。

#### 步骤 3: 验证 Hooks 是否激活

重新加载后，执行一些操作来触发 hooks：

1. **读取一个文件** - 触发 tool-use-hook
2. **搜索代码** - 触发 tool-use-hook
3. **发送一条消息** - 触发 user-prompt-hook

#### 步骤 4: 检查观察是否被捕获

```bash
# 等待几秒钟让 hooks 处理
sleep 5

# 检查数据库
sqlite3 ~/.claude-mem/claude-mem.db "SELECT COUNT(*) FROM observations;"

# 应该看到数字 > 0
```

#### 步骤 5: 测试搜索功能

在 Kiro 中使用 Claude-Mem MCP 工具：

```javascript
// 搜索最近的工作
mcp_claude_mem_search({ query: "recent work", limit: 10 })

// 获取最近的上下文
mcp_claude_mem_get_recent_context({ limit: 10 })

// 查看时间线
mcp_claude_mem_timeline({ limit: 20 })
```

### 验证修复

运行诊断脚本确认：

```bash
./scripts/diagnose_claude_mem.sh
```

应该看到：
- ✓ 观察记录数 > 0
- ✓ Chroma 目录存在

### 如果问题仍然存在

#### 选项 1: 完全重置 Claude-Mem

```bash
# 1. 备份数据
cp -r ~/.claude-mem ~/.claude-mem.backup-$(date +%Y%m%d)

# 2. 停止 Worker
./scripts/restart_claude_mem.sh

# 3. 删除所有数据
rm -rf ~/.claude-mem

# 4. 重新初始化
mkdir -p ~/.claude-mem/logs

# 5. 启动 Worker
./scripts/start_claude_mem_worker.sh

# 6. 重新加载 Kiro IDE 窗口
```

#### 选项 2: 检查 Kiro IDE 日志

查看 Kiro IDE 的输出日志，看是否有关于 hooks 的错误信息。

#### 选项 3: 手动测试 Hooks

```bash
# 测试 tool-use hook
cd .kiro/hooks/scripts
echo '{"toolName":"TestTool","toolInput":"{}","toolOutput":"test"}' | node tool-use-hook.js
```

### 常见问题

#### Q: 为什么 Chroma 目录不存在？

A: Chroma 目录会在第一次有观察记录时自动创建。如果没有观察记录，就不会有 Chroma 目录。

#### Q: Hooks 已安装但为什么不触发？

A: Hooks 需要 Kiro IDE 正确加载和激活。重新加载 IDE 窗口通常可以解决这个问题。

#### Q: 如何确认 Hooks 是否正在运行？

A: 查看 Worker 日志：

```bash
tail -f ~/.claude-mem/logs/worker-$(date +%Y-%m-%d).log
```

执行一些操作（读取文件、搜索等），应该看到类似的日志：
```
[INFO] [HTTP] → POST /api/observations
[INFO] [CAPTURE] Captured observation: tool_use
```

#### Q: 搜索返回 "No results found"

A: 这意味着：
1. 数据库中没有观察记录，或
2. Chroma 向量数据库没有索引，或
3. 搜索查询没有匹配到任何内容

先确认数据库中有观察记录：
```bash
sqlite3 ~/.claude-mem/claude-mem.db "SELECT COUNT(*) FROM observations;"
```

### 监控和维护

#### 定期检查

```bash
# 每天运行一次诊断
./scripts/diagnose_claude_mem.sh

# 查看最近的观察
sqlite3 ~/.claude-mem/claude-mem.db "SELECT id, type, title, created_at FROM observations ORDER BY created_at DESC LIMIT 10;"
```

#### 清理旧数据

```bash
# 删除 30 天前的观察
sqlite3 ~/.claude-mem/claude-mem.db "DELETE FROM observations WHERE created_at < datetime('now', '-30 days');"

# 重建 Chroma 索引
./scripts/fix_claude_mem_chroma.sh
```

### 相关脚本

- `./scripts/diagnose_claude_mem.sh` - 诊断工具
- `./scripts/restart_claude_mem.sh` - 重启 Worker
- `./scripts/fix_claude_mem_chroma.sh` - 修复 Chroma
- `./scripts/start_claude_mem_worker.sh` - 启动 Worker
- `./scripts/debug_claude_mem.sh` - 调试工具

### 更多帮助

- 文档: `scripts/README_CLAUDE_MEM.md`
- 快速参考: `scripts/CLAUDE_MEM_QUICK_REF.md`
- 维护指南: `scripts/CLAUDE_MEM_MAINTENANCE.md`
