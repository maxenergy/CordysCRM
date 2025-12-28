# Claude-Mem 快速参考卡

## 🚀 快速修复

```bash
# 1. 诊断问题
./scripts/debug_claude_mem.sh

# 2. 修复 Chroma 错误（推荐）
./scripts/fix_claude_mem_sqlite_config.sh

# 3. 完整修复（如果问题严重）
./scripts/fix_claude_mem_complete.sh
```

## 📊 常用命令

### 服务管理
```bash
# 重启服务
./scripts/restart_claude_mem.sh

# 检查服务状态
curl -s http://127.0.0.1:37777/api/readiness | jq '.'

# 查看服务统计
curl -s http://127.0.0.1:37777/api/stats | jq '.'
```

### 日志查看
```bash
# 实时日志
tail -f ~/.claude-mem/logs/worker-$(date +%Y-%m-%d).log

# 搜索错误
grep -i error ~/.claude-mem/logs/worker-*.log

# 搜索 Chroma 相关
grep -i chroma ~/.claude-mem/logs/worker-*.log
```

### 数据库检查
```bash
# 主数据库完整性
sqlite3 ~/.claude-mem/claude-mem.db "PRAGMA integrity_check;"

# 向量数据库完整性
sqlite3 ~/.claude-mem/vector-db/chroma.sqlite3 "PRAGMA integrity_check;"

# 查看会话数
sqlite3 ~/.claude-mem/claude-mem.db "SELECT COUNT(*) FROM sessions;"

# 查看观察数
sqlite3 ~/.claude-mem/claude-mem.db "SELECT COUNT(*) FROM observations;"
```

### 数据库优化
```bash
# 优化主数据库
sqlite3 ~/.claude-mem/claude-mem.db "VACUUM; ANALYZE;"

# 优化向量数据库
sqlite3 ~/.claude-mem/vector-db/chroma.sqlite3 "VACUUM; ANALYZE;"
```

## 🔍 故障排查

### 问题: Worker 服务未响应
```bash
# 1. 检查进程
ps aux | grep claude-mem

# 2. 检查端口
netstat -tuln | grep 37777

# 3. 查看日志
tail -50 ~/.claude-mem/logs/worker-$(date +%Y-%m-%d).log

# 4. 重启服务
./scripts/restart_claude_mem.sh
```

### 问题: Chroma 同步错误
```bash
# 快速修复
./scripts/fix_claude_mem_sqlite_config.sh

# 验证修复
tail -f ~/.claude-mem/logs/worker-$(date +%Y-%m-%d).log | grep -i chroma
```

### 问题: 数据库损坏
```bash
# 完整修复（会备份数据）
./scripts/fix_claude_mem_complete.sh

# 手动检查
sqlite3 ~/.claude-mem/claude-mem.db "PRAGMA integrity_check;"
```

### 问题: 观察未被捕获
```bash
# 1. 检查 Hooks
ls -la .kiro/hooks/

# 2. 检查配置
cat ~/.kiro/settings/mcp.json | jq '.mcpServers["claude-mem"]'

# 3. 重新连接 MCP
# 在 Kiro IDE 中断开并重新连接 claude-mem
```

## 📁 重要文件位置

```
~/.claude-mem/
├── claude-mem.db              # 主数据库
├── vector-db/
│   └── chroma.sqlite3         # 向量数据库
├── settings.json              # 配置文件
├── logs/                      # 日志目录
│   └── worker-YYYY-MM-DD.log
├── backup-*/                  # 备份目录
└── worker.pid                 # 进程 PID

~/.kiro/settings/
└── mcp.json                   # MCP 配置

.kiro/hooks/                   # Kiro Hooks
├── memory-hooks.json
├── on-session-start.json
├── on-session-end.json
├── on-tool-use.json
└── on-user-prompt.json
```

## 🔧 配置调整

### 调整上下文观察数量
```bash
# 编辑配置
nano ~/.claude-mem/settings.json

# 修改这一行
"CLAUDE_MEM_CONTEXT_OBSERVATIONS": "50"  # 默认 50

# 重启服务
./scripts/restart_claude_mem.sh
```

### 调整日志级别
```bash
# 编辑配置
nano ~/.claude-mem/settings.json

# 修改这一行
"CLAUDE_MEM_LOG_LEVEL": "INFO"  # DEBUG, INFO, WARN, ERROR

# 重启服务
./scripts/restart_claude_mem.sh
```

## 💾 备份和恢复

### 手动备份
```bash
BACKUP_DIR=~/.claude-mem/backup-manual-$(date +%Y%m%d-%H%M%S)
mkdir -p "$BACKUP_DIR"
cp ~/.claude-mem/claude-mem.db "$BACKUP_DIR/"
cp -r ~/.claude-mem/vector-db "$BACKUP_DIR/"
cp ~/.claude-mem/settings.json "$BACKUP_DIR/"
echo "备份完成: $BACKUP_DIR"
```

### 恢复备份
```bash
# 停止服务
./scripts/restart_claude_mem.sh stop

# 恢复（替换 BACKUP_DIR）
BACKUP_DIR=~/.claude-mem/backup-20251227-162610
cp "$BACKUP_DIR/claude-mem.db" ~/.claude-mem/
cp -r "$BACKUP_DIR/vector-db" ~/.claude-mem/
cp "$BACKUP_DIR/settings.json" ~/.claude-mem/

# 重启服务
./scripts/restart_claude_mem.sh
```

## 🧹 清理维护

### 清理旧备份
```bash
# 删除 30 天前的备份
find ~/.claude-mem/backup-* -maxdepth 0 -mtime +30 -exec rm -rf {} \;
```

### 清理旧日志
```bash
# 删除 30 天前的日志
find ~/.claude-mem/logs/ -name "worker-*.log" -mtime +30 -delete
```

### 查看磁盘使用
```bash
# 总大小
du -sh ~/.claude-mem/

# 详细大小
du -h ~/.claude-mem/* | sort -h
```

## 🌐 Web 界面

访问 Claude-Mem Web 界面：
```
http://127.0.0.1:37777
```

功能：
- 实时观察流
- 会话浏览
- 搜索界面
- 统计信息
- 配置管理

## 📚 文档链接

- **维护指南**: `scripts/CLAUDE_MEM_MAINTENANCE.md`
- **修复总结**: `scripts/CLAUDE_MEM_FIX_SUMMARY.md`
- **官方文档**: https://docs.claude-mem.ai
- **GitHub**: https://github.com/thedotmack/claude-mem

## ⚡ 一键命令

```bash
# 完整健康检查
./scripts/debug_claude_mem.sh > ~/claude-mem-health.log && cat ~/claude-mem-health.log

# 快速修复并验证
./scripts/fix_claude_mem_sqlite_config.sh && sleep 3 && curl -s http://127.0.0.1:37777/api/readiness

# 查看最近错误
tail -100 ~/.claude-mem/logs/worker-$(date +%Y-%m-%d).log | grep -i error

# 数据库统计
echo "会话: $(sqlite3 ~/.claude-mem/claude-mem.db 'SELECT COUNT(*) FROM sessions;')" && \
echo "观察: $(sqlite3 ~/.claude-mem/claude-mem.db 'SELECT COUNT(*) FROM observations;')"
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

# 4. 如果还不行，查看日志
tail -100 ~/.claude-mem/logs/worker-$(date +%Y-%m-%d).log
```

---

**提示**: 将此文件保存为书签，随时查阅！
