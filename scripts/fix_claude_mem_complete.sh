#!/bin/bash
# Claude-Mem 完整修复脚本 (SQLite3 + FAISS 版本)
# 适用于使用 SQLite3 作为向量数据库的 Claude-Mem 配置

set -e

echo "🔧 Claude-Mem 完整修复脚本"
echo "================================"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置
CURRENT_PROJECT=$(pwd)
MCP_CONFIG=~/.kiro/settings/mcp.json
CLAUDE_MEM_DIR=~/.claude-mem
KIRO_MEM_DIR="/home/rogers/source/develop/kiro-mem"
WORKER_CLI="$KIRO_MEM_DIR/claude-mem/plugin/scripts/worker-cli.js"

# 检查函数
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}❌ 错误: 未找到 $1 命令${NC}"
        echo "请先安装 $1"
        exit 1
    fi
}

# 步骤 1: 检查依赖
echo "📋 步骤 1/8: 检查依赖..."
check_command "bun"
check_command "sqlite3"
check_command "jq"
check_command "curl"
echo -e "${GREEN}✅ 所有依赖已安装${NC}"
echo ""

# 步骤 2: 停止现有服务
echo "🛑 步骤 2/8: 停止现有 Claude-Mem 服务..."
if [ -f "$WORKER_CLI" ]; then
    bun "$WORKER_CLI" stop 2>/dev/null || true
else
    # 手动停止进程
    pkill -f "claude-mem.*worker" 2>/dev/null || true
fi

# 确保进程已停止
sleep 2
if pgrep -f "claude-mem.*worker" > /dev/null; then
    echo -e "${YELLOW}⚠️  强制停止残留进程...${NC}"
    pkill -9 -f "claude-mem.*worker" 2>/dev/null || true
    sleep 1
fi
echo -e "${GREEN}✅ 服务已停止${NC}"
echo ""

# 步骤 3: 备份现有数据
echo "💾 步骤 3/8: 备份现有数据..."
BACKUP_DIR="$CLAUDE_MEM_DIR/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

if [ -f "$CLAUDE_MEM_DIR/claude-mem.db" ]; then
    cp "$CLAUDE_MEM_DIR/claude-mem.db" "$BACKUP_DIR/" 2>/dev/null || true
    echo "   ✓ 已备份主数据库"
fi

if [ -d "$CLAUDE_MEM_DIR/vector-db" ]; then
    cp -r "$CLAUDE_MEM_DIR/vector-db" "$BACKUP_DIR/" 2>/dev/null || true
    echo "   ✓ 已备份向量数据库"
fi

if [ -f "$CLAUDE_MEM_DIR/settings.json" ]; then
    cp "$CLAUDE_MEM_DIR/settings.json" "$BACKUP_DIR/" 2>/dev/null || true
    echo "   ✓ 已备份配置文件"
fi

echo -e "${GREEN}✅ 备份保存到: $BACKUP_DIR${NC}"
echo ""

# 步骤 4: 清理损坏的数据
echo "🧹 步骤 4/8: 清理可能损坏的数据..."

# 检查主数据库完整性
if [ -f "$CLAUDE_MEM_DIR/claude-mem.db" ]; then
    echo "   检查主数据库完整性..."
    if sqlite3 "$CLAUDE_MEM_DIR/claude-mem.db" "PRAGMA integrity_check;" | grep -q "ok"; then
        echo "   ✓ 主数据库完整性正常"
    else
        echo -e "${YELLOW}   ⚠️  主数据库可能损坏，将重置${NC}"
        rm -f "$CLAUDE_MEM_DIR/claude-mem.db"
        rm -f "$CLAUDE_MEM_DIR/claude-mem.db-shm"
        rm -f "$CLAUDE_MEM_DIR/claude-mem.db-wal"
    fi
fi

# 清理向量数据库（SQLite3 + FAISS）
if [ -d "$CLAUDE_MEM_DIR/vector-db" ]; then
    echo "   检查向量数据库..."
    if [ -f "$CLAUDE_MEM_DIR/vector-db/chroma.sqlite3" ]; then
        if sqlite3 "$CLAUDE_MEM_DIR/vector-db/chroma.sqlite3" "PRAGMA integrity_check;" | grep -q "ok"; then
            echo "   ✓ 向量数据库完整性正常"
        else
            echo -e "${YELLOW}   ⚠️  向量数据库可能损坏，将重置${NC}"
            rm -rf "$CLAUDE_MEM_DIR/vector-db"
        fi
    fi
fi

# 清理 WAL 文件
rm -f "$CLAUDE_MEM_DIR/claude-mem.db-shm" 2>/dev/null || true
rm -f "$CLAUDE_MEM_DIR/claude-mem.db-wal" 2>/dev/null || true

echo -e "${GREEN}✅ 清理完成${NC}"
echo ""

# 步骤 5: 更新 MCP 配置
echo "⚙️  步骤 5/8: 更新 MCP 配置..."
if [ -f "$MCP_CONFIG" ]; then
    # 备份 MCP 配置
    cp "$MCP_CONFIG" "$MCP_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
    
    # 更新项目路径
    cat "$MCP_CONFIG" | jq \
      --arg project "$CURRENT_PROJECT" \
      '.mcpServers["claude-mem"].env.CLAUDE_MEM_SOURCE_PROJECT = $project' \
      > "$MCP_CONFIG.tmp" && mv "$MCP_CONFIG.tmp" "$MCP_CONFIG"
    
    echo "   ✓ 已更新项目路径: $CURRENT_PROJECT"
    echo -e "${GREEN}✅ MCP 配置已更新${NC}"
else
    echo -e "${RED}❌ 未找到 MCP 配置文件: $MCP_CONFIG${NC}"
    exit 1
fi
echo ""

# 步骤 6: 更新 Claude-Mem 设置
echo "📝 步骤 6/8: 更新 Claude-Mem 设置..."
SETTINGS_FILE="$CLAUDE_MEM_DIR/settings.json"

# 创建或更新设置文件
cat > "$SETTINGS_FILE" << EOF
{
  "model": "claude-sonnet-4-5",
  "workerPort": 37777,
  "workerHost": "127.0.0.1",
  "contextObservations": 50,
  "logLevel": "INFO",
  "vectorDb": "sqlite3",
  "embeddingModel": "text-embedding-3-small",
  "maxTokens": 4096
}
EOF

echo "   ✓ 已创建/更新设置文件"
echo -e "${GREEN}✅ 设置已更新${NC}"
echo ""

# 步骤 7: 重启 Worker 服务
echo "🚀 步骤 7/8: 启动 Claude-Mem Worker 服务..."
if [ -f "$WORKER_CLI" ]; then
    cd "$KIRO_MEM_DIR"
    bun "$WORKER_CLI" start
    
    # 等待服务启动
    echo "   等待服务启动..."
    sleep 3
    
    # 检查服务状态
    MAX_RETRIES=5
    RETRY_COUNT=0
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if curl -s http://127.0.0.1:37777/api/readiness > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Worker 服务已成功启动${NC}"
            break
        fi
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            echo "   重试 $RETRY_COUNT/$MAX_RETRIES..."
            sleep 2
        fi
    done
    
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo -e "${RED}❌ Worker 服务启动失败${NC}"
        echo "请检查日志: tail -f ~/.claude-mem/logs/worker-$(date +%Y-%m-%d).log"
        exit 1
    fi
else
    echo -e "${RED}❌ 未找到 worker-cli.js: $WORKER_CLI${NC}"
    exit 1
fi
echo ""

# 步骤 8: 验证服务
echo "🔍 步骤 8/8: 验证服务状态..."

# 检查 API 可用性
echo "   检查 API 端点..."
if curl -s http://127.0.0.1:37777/api/readiness | grep -q '"status":"ready"'; then
    echo "   ✓ Readiness 端点正常"
else
    echo -e "${YELLOW}   ⚠️  Readiness 端点响应异常${NC}"
fi

# 显示服务统计
echo ""
echo "📊 服务统计信息:"
curl -s http://127.0.0.1:37777/api/stats 2>/dev/null | jq '.' || echo "   无法获取统计信息"

# 检查数据库
echo ""
echo "💾 数据库状态:"
if [ -f "$CLAUDE_MEM_DIR/claude-mem.db" ]; then
    echo "   ✓ 主数据库: $(du -h "$CLAUDE_MEM_DIR/claude-mem.db" | cut -f1)"
    echo "   会话数: $(sqlite3 "$CLAUDE_MEM_DIR/claude-mem.db" "SELECT COUNT(*) FROM sessions;" 2>/dev/null || echo "0")"
    echo "   观察数: $(sqlite3 "$CLAUDE_MEM_DIR/claude-mem.db" "SELECT COUNT(*) FROM observations;" 2>/dev/null || echo "0")"
fi

if [ -f "$CLAUDE_MEM_DIR/vector-db/chroma.sqlite3" ]; then
    echo "   ✓ 向量数据库: $(du -h "$CLAUDE_MEM_DIR/vector-db/chroma.sqlite3" | cut -f1)"
fi

echo ""
echo "================================"
echo -e "${GREEN}✅ Claude-Mem 修复完成！${NC}"
echo "================================"
echo ""
echo "📝 后续步骤:"
echo "   1. 在 Kiro IDE 中重新连接 claude-mem MCP 服务器"
echo "   2. 执行一些操作（读取文件、搜索等）测试捕获功能"
echo "   3. 访问 http://127.0.0.1:37777 查看 Web 界面"
echo "   4. 使用 Claude-Mem 搜索功能测试记忆检索"
echo ""
echo "🔍 调试命令:"
echo "   查看日志: tail -f ~/.claude-mem/logs/worker-$(date +%Y-%m-%d).log"
echo "   检查状态: bun $WORKER_CLI status"
echo "   重启服务: bun $WORKER_CLI restart"
echo ""
echo "💾 备份位置: $BACKUP_DIR"
echo ""
