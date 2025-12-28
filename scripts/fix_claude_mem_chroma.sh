#!/bin/bash
# 修复 Claude-Mem Chroma 向量数据库问题

set -e

echo "🔧 开始修复 Claude-Mem Chroma 问题..."

# 1. 停止 worker 服务
echo "1️⃣ 停止 Claude-Mem worker 服务..."
if pgrep -f "claude-mem.*worker" > /dev/null; then
    pkill -f "claude-mem.*worker" || true
    sleep 2
fi

# 2. 备份现有数据
echo "2️⃣ 备份现有数据..."
BACKUP_DIR=~/.claude-mem/backup-$(date +%Y%m%d-%H%M%S)
mkdir -p "$BACKUP_DIR"
if [ -d ~/.claude-mem/chroma ]; then
    cp -r ~/.claude-mem/chroma "$BACKUP_DIR/" || true
fi
if [ -f ~/.claude-mem/claude-mem.db ]; then
    cp ~/.claude-mem/claude-mem.db "$BACKUP_DIR/" || true
fi
echo "   备份保存到: $BACKUP_DIR"

# 3. 清理 Chroma 数据
echo "3️⃣ 清理 Chroma 向量数据库..."
if [ -d ~/.claude-mem/chroma ]; then
    rm -rf ~/.claude-mem/chroma
    echo "   已删除 ~/.claude-mem/chroma"
fi

# 4. 重新初始化数据库
echo "4️⃣ 重新初始化数据库..."
# Chroma 会在下次启动时自动重建

# 5. 重启 worker 服务
echo "5️⃣ 重启 Claude-Mem worker 服务..."
KIRO_MEM_DIR="/home/rogers/source/develop/kiro-mem"
if [ -d "$KIRO_MEM_DIR" ]; then
    cd "$KIRO_MEM_DIR"
    ./stop-worker-service.sh || true
    sleep 2
    ./start-worker-service.sh
else
    echo "❌ 找不到 kiro-mem 目录: $KIRO_MEM_DIR"
    exit 1
fi

# 等待服务启动
echo "6️⃣ 等待服务启动..."
sleep 3

# 7. 检查服务状态
echo "7️⃣ 检查服务状态..."
if curl -s http://localhost:37777/api/readiness | grep -q '"status":"ready"'; then
    echo "✅ Claude-Mem 服务已成功启动"
    echo ""
    echo "📊 服务状态:"
    curl -s http://localhost:37777/api/stats | jq '.'
else
    echo "❌ 服务启动失败，请检查日志:"
    echo "   tail -f ~/.claude-mem/logs/worker-$(date +%Y-%m-%d).log"
    exit 1
fi

echo ""
echo "✅ 修复完成！"
echo ""
echo "📝 注意事项:"
echo "   1. Chroma 向量数据库已重置，历史观察需要重新索引"
echo "   2. 新的会话将正常捕获观察记录"
echo "   3. 备份数据保存在: $BACKUP_DIR"
echo ""
echo "🔍 测试建议:"
echo "   1. 在 Kiro 中执行一些操作（读取文件、搜索等）"
echo "   2. 访问 http://localhost:37777 查看观察流"
echo "   3. 使用 Claude-Mem 搜索功能测试"
