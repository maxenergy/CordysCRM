# Claude-Mem 维护脚本

Claude-Mem 是 Kiro IDE 的持久化记忆系统，使用 SQLite3 + FAISS 作为存储方案。

## 🚀 快速开始

```bash
# 1. 诊断当前状态
./scripts/debug_claude_mem.sh

# 2. 修复 Chroma 同步错误（最常见问题）
./scripts/fix_claude_mem_sqlite_config.sh

# 3. 完整修复（如果有严重问题）
./scripts/fix_claude_mem_complete.sh
```

## 📋 可用脚本

| 脚本 | 用途 | 何时使用 |
|------|------|----------|
| `debug_claude_mem.sh` | 全面诊断系统状态 | 随时检查健康状况 |
| `fix_claude_mem_sqlite_config.sh` | 修复 SQLite3 配置 | Chroma 同步错误 |
| `fix_claude_mem_complete.sh` | 完整修复所有组件 | 严重问题或数据库损坏 |
| `fix_claude_mem_config.sh` | 更新项目路径 | 切换项目时 |
| `restart_claude_mem.sh` | 重启 Worker 服务 | 日常维护 |
| `fix_claude_mem_chroma.sh` | Chroma 服务器修复 | （已过时，保留用于参考） |

## 📚 文档

### 快速参考
**文件**: `CLAUDE_MEM_QUICK_REF.md`

常用命令、故障排查、一键命令等快速参考。

### 维护指南
**文件**: `CLAUDE_MEM_MAINTENANCE.md`

详细的维护文档，包括：
- 系统架构说明
- 脚本详细说明
- 常见问题排查
- 数据备份和恢复
- 性能优化
- 监控和维护

### 修复总结
**文件**: `CLAUDE_MEM_FIX_SUMMARY.md`

当前问题诊断和解决方案总结。

## 🔍 常见问题

### Q: 看到 "Chroma sync failed" 错误？

**A**: 运行快速修复：
```bash
./scripts/fix_claude_mem_sqlite_config.sh
```

这会禁用 Chroma MCP 同步，因为我们使用 SQLite3 作为向量数据库。

### Q: Worker 服务无法启动？

**A**: 运行完整修复：
```bash
./scripts/fix_claude_mem_complete.sh
```

### Q: 观察未被捕获？

**A**: 检查诊断：
```bash
./scripts/debug_claude_mem.sh
```

然后在 Kiro IDE 中重新连接 claude-mem MCP 服务器。

### Q: 数据库损坏？

**A**: 运行完整修复（会自动备份）：
```bash
./scripts/fix_claude_mem_complete.sh
```

## 🌐 Web 界面

访问 Claude-Mem Web 界面查看实时状态：
```
http://127.0.0.1:37777
```

## 📊 快速命令

```bash
# 查看服务状态
curl -s http://127.0.0.1:37777/api/readiness | jq '.'

# 查看统计信息
curl -s http://127.0.0.1:37777/api/stats | jq '.'

# 查看实时日志
tail -f ~/.claude-mem/logs/worker-$(date +%Y-%m-%d).log

# 检查数据库
sqlite3 ~/.claude-mem/claude-mem.db "SELECT COUNT(*) FROM observations;"
```

## 🆘 紧急救援

如果一切都不工作：

```bash
# 1. 完全停止
pkill -9 -f claude-mem

# 2. 备份数据
cp -r ~/.claude-mem ~/.claude-mem.emergency-backup

# 3. 完整修复
./scripts/fix_claude_mem_complete.sh
```

## 📖 更多信息

- **官方文档**: https://docs.claude-mem.ai
- **GitHub**: https://github.com/thedotmack/claude-mem
- **问题报告**: https://github.com/thedotmack/claude-mem/issues

---

**提示**: 建议先阅读 `CLAUDE_MEM_QUICK_REF.md` 获取快速参考，然后查看 `CLAUDE_MEM_MAINTENANCE.md` 了解详细信息。
