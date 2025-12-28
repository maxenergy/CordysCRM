# Claude-Mem 维护脚本文档

本文档说明 Claude-Mem (SQLite3 + FAISS 版本) 的维护和故障排除脚本。

## 系统架构

Claude-Mem 使用以下存储方案：
- **主数据库**: `~/.claude-mem/claude-mem.db` (SQLite3)
  - 存储会话、观察、提示等结构化数据
- **向量数据库**: `~/.claude-mem/vector-db/chroma.sqlite3` (SQLite3)
  - 存储语义嵌入向量，用于相似度搜索
  - 可选 FAISS 索引文件用于加速向量检索
- **Worker 服务**: HTTP 服务器 (端口 37777)
  - 处理记忆捕获、搜索和摘要生成

## 可用脚本

### 1. 诊断脚本 - `debug_claude_mem.sh`

**用途**: 全面诊断 Claude-Mem 系统状态

**功能**:
- 检查 Worker 服务运行状态
- 验证主数据库和向量数据库完整性
- 检查 Kiro Hooks 安装状态
- 显示配置信息
- 查看最近的日志
- 检查进程和端口占用
- 测试 API 端点

**使用方法**:
```bash
./scripts/debug_claude_mem.sh
```

**何时使用**:
- 怀疑 Claude-Mem 工作不正常时
- 定期健康检查
- 在执行修复前了解当前状态

### 2. 完整修复脚本 - `fix_claude_mem_complete.sh`

**用途**: 全面修复 Claude-Mem 系统问题

**功能**:
1. 检查所有必需依赖 (bun, sqlite3, jq, curl)
2. 停止现有 Worker 服务
3. 备份所有数据（数据库、向量数据库、配置）
4. 清理损坏的数据文件
5. 更新 MCP 配置（项目路径）
6. 更新 Claude-Mem 设置
7. 重启 Worker 服务
8. 验证服务状态

**使用方法**:
```bash
./scripts/fix_claude_mem_complete.sh
```

**何时使用**:
- Worker 服务无法启动
- 数据库损坏或完整性检查失败
- 向量搜索不工作
- 切换项目后需要重新配置
- 系统升级后出现问题

**注意事项**:
- 脚本会自动备份所有数据到 `~/.claude-mem/backup-YYYYMMDD-HHMMSS/`
- 如果数据库损坏，会被重置（但有备份）
- 执行后需要在 Kiro IDE 中重新连接 MCP 服务器

### 3. 配置修复脚本 - `fix_claude_mem_config.sh`

**用途**: 仅更新 MCP 配置中的项目路径

**功能**:
- 备份 MCP 配置
- 更新 `CLAUDE_MEM_SOURCE_PROJECT` 为当前项目路径
- 显示新配置

**使用方法**:
```bash
./scripts/fix_claude_mem_config.sh
```

**何时使用**:
- 切换到新项目时
- MCP 配置中的项目路径不正确
- 不需要完整修复，只需更新配置

### 4. 重启脚本 - `restart_claude_mem.sh`

**用途**: 简单重启 Worker 服务

**功能**:
- 停止 Worker 服务
- 启动 Worker 服务
- 检查服务状态

**使用方法**:
```bash
./scripts/restart_claude_mem.sh
```

**何时使用**:
- 服务响应缓慢
- 配置更改后需要重启
- 日常维护重启

### 5. Chroma 修复脚本 - `fix_claude_mem_chroma.sh`

**用途**: 专门处理向量数据库问题（已过时，保留用于参考）

**注意**: 此脚本是为独立 Chroma 服务器设计的。当前系统使用 SQLite3 作为向量数据库，建议使用 `fix_claude_mem_complete.sh` 代替。

## 常见问题排查

### 问题 1: Worker 服务无法启动

**症状**:
```
❌ Worker 服务未响应
❌ 端口 37777 未被占用
```

**解决方案**:
1. 运行诊断: `./scripts/debug_claude_mem.sh`
2. 检查日志: `tail -f ~/.claude-mem/logs/worker-$(date +%Y-%m-%d).log`
3. 执行完整修复: `./scripts/fix_claude_mem_complete.sh`

### 问题 2: 数据库损坏

**症状**:
```
⚠️  数据库可能损坏
⚠️  向量数据库可能损坏
```

**解决方案**:
1. 执行完整修复: `./scripts/fix_claude_mem_complete.sh`
2. 脚本会自动备份并重置损坏的数据库
3. 如需恢复数据，从备份目录手动恢复

### 问题 3: 观察未被捕获

**症状**:
- 执行操作后，观察数量不增加
- 搜索返回空结果

**可能原因**:
1. Worker 服务未运行
2. Kiro Hooks 未安装
3. MCP 服务器未连接

**解决方案**:
1. 运行诊断: `./scripts/debug_claude_mem.sh`
2. 检查 Hooks: `ls -la .kiro/hooks/`
3. 在 Kiro IDE 中重新连接 claude-mem MCP 服务器
4. 如果问题持续，执行完整修复

### 问题 4: 搜索不返回结果

**症状**:
- Worker 服务运行正常
- 观察已被捕获
- 但搜索返回空结果或错误

**可能原因**:
1. 向量数据库损坏
2. 嵌入模型配置错误
3. 向量索引未建立

**解决方案**:
1. 检查向量数据库: `sqlite3 ~/.claude-mem/vector-db/chroma.sqlite3 "PRAGMA integrity_check;"`
2. 执行完整修复: `./scripts/fix_claude_mem_complete.sh`
3. 等待新观察被捕获并索引

### 问题 5: 切换项目后无法工作

**症状**:
- 在新项目中，Claude-Mem 不捕获观察
- 或者捕获到错误项目的观察

**解决方案**:
1. 在新项目目录中执行: `./scripts/fix_claude_mem_config.sh`
2. 或执行完整修复: `./scripts/fix_claude_mem_complete.sh`
3. 在 Kiro IDE 中重新连接 MCP 服务器

## 数据备份和恢复

### 自动备份

所有修复脚本都会自动备份数据到：
```
~/.claude-mem/backup-YYYYMMDD-HHMMSS/
├── claude-mem.db          # 主数据库
├── vector-db/             # 向量数据库
│   └── chroma.sqlite3
└── settings.json          # 配置文件
```

### 手动备份

```bash
# 创建完整备份
BACKUP_DIR=~/.claude-mem/backup-manual-$(date +%Y%m%d-%H%M%S)
mkdir -p "$BACKUP_DIR"
cp ~/.claude-mem/claude-mem.db "$BACKUP_DIR/"
cp -r ~/.claude-mem/vector-db "$BACKUP_DIR/"
cp ~/.claude-mem/settings.json "$BACKUP_DIR/"
```

### 恢复备份

```bash
# 停止服务
./scripts/restart_claude_mem.sh stop

# 恢复数据（替换 BACKUP_DIR 为实际备份目录）
BACKUP_DIR=~/.claude-mem/backup-20251227-162610
cp "$BACKUP_DIR/claude-mem.db" ~/.claude-mem/
cp -r "$BACKUP_DIR/vector-db" ~/.claude-mem/
cp "$BACKUP_DIR/settings.json" ~/.claude-mem/

# 重启服务
./scripts/restart_claude_mem.sh
```

## 日志管理

### 查看日志

```bash
# 查看今天的日志
tail -f ~/.claude-mem/logs/worker-$(date +%Y-%m-%d).log

# 查看最近的日志
ls -lt ~/.claude-mem/logs/*.log | head -5

# 搜索错误
grep -i error ~/.claude-mem/logs/worker-*.log
```

### 清理旧日志

```bash
# 删除 30 天前的日志
find ~/.claude-mem/logs/ -name "worker-*.log" -mtime +30 -delete
```

## 性能优化

### 数据库优化

```bash
# 优化主数据库
sqlite3 ~/.claude-mem/claude-mem.db "VACUUM; ANALYZE;"

# 优化向量数据库
sqlite3 ~/.claude-mem/vector-db/chroma.sqlite3 "VACUUM; ANALYZE;"
```

### 调整上下文观察数量

编辑 `~/.claude-mem/settings.json`:
```json
{
  "contextObservations": 50  // 减少以节省 token，增加以获得更多上下文
}
```

## 监控和维护

### 定期健康检查

建议每周运行一次诊断：
```bash
./scripts/debug_claude_mem.sh > ~/claude-mem-health-$(date +%Y%m%d).log
```

### 监控磁盘使用

```bash
# 检查数据库大小
du -sh ~/.claude-mem/

# 详细大小
du -h ~/.claude-mem/* | sort -h
```

### 清理策略

如果磁盘空间不足，可以：
1. 删除旧备份: `rm -rf ~/.claude-mem/backup-*`
2. 清理旧日志: `find ~/.claude-mem/logs/ -mtime +30 -delete`
3. 重置数据库（会丢失历史）: `./scripts/fix_claude_mem_complete.sh`

## 故障排除流程图

```
问题出现
    ↓
运行诊断脚本
    ↓
Worker 服务正常？
    ├─ 否 → 执行完整修复
    └─ 是 → 数据库完整？
              ├─ 否 → 执行完整修复
              └─ 是 → 配置正确？
                        ├─ 否 → 执行配置修复
                        └─ 是 → 检查日志
                                  ↓
                              查找具体错误
                                  ↓
                              针对性修复
```

## 联系和支持

- **Claude-Mem 文档**: https://docs.claude-mem.ai
- **GitHub**: https://github.com/thedotmack/claude-mem
- **问题报告**: https://github.com/thedotmack/claude-mem/issues

## 版本信息

- 脚本版本: 1.0.0
- 适用于: Claude-Mem with SQLite3 + FAISS
- 最后更新: 2024-12-27
