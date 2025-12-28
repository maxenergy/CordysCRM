#!/bin/bash
# 修复 Claude-Mem SQLite3 配置（禁用 Chroma MCP 同步）

set -e

echo "🔧 修复 Claude-Mem SQLite3 配置..."
echo ""

SETTINGS_FILE=~/.claude-mem/settings.json

# 备份配置
echo "1️⃣ 备份现有配置..."
cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup.$(date +%Y%m%d_%H%M%S)"
echo "   ✅ 备份完成"
echo ""

# 更新配置，禁用 Chroma MCP 同步
echo "2️⃣ 更新配置..."
cat "$SETTINGS_FILE" | jq '. + {
  "CLAUDE_MEM_DISABLE_CHROMA_SYNC": "true",
  "CLAUDE_MEM_VECTOR_DB": "sqlite3",
  "CLAUDE_MEM_EMBEDDING_PROVIDER": "openai",
  "CLAUDE_MEM_EMBEDDING_MODEL": "text-embedding-3-small"
}' > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

echo "   ✅ 配置已更新"
echo ""

# 显示新配置
echo "3️⃣ 新配置:"
cat "$SETTINGS_FILE" | jq '{
  CLAUDE_MEM_DISABLE_CHROMA_SYNC,
  CLAUDE_MEM_VECTOR_DB,
  CLAUDE_MEM_EMBEDDING_PROVIDER,
  CLAUDE_MEM_EMBEDDING_MODEL
}'
echo ""

# 重启服务
echo "4️⃣ 重启 Worker 服务..."
WORKER_CLI="/home/rogers/source/develop/kiro-mem/claude-mem/plugin/scripts/worker-cli.js"

if [ -f "$WORKER_CLI" ]; then
    bun "$WORKER_CLI" restart
    sleep 3
    
    # 检查服务状态
    if curl -s http://127.0.0.1:37777/api/readiness | grep -q '"status":"ready"'; then
        echo "   ✅ 服务重启成功"
    else
        echo "   ⚠️  服务可能未正常启动，请检查日志"
    fi
else
    echo "   ⚠️  未找到 worker-cli.js，请手动重启服务"
fi
echo ""

echo "✅ 配置修复完成！"
echo ""
echo "📝 说明:"
echo "   - 已禁用 Chroma MCP 同步"
echo "   - 使用 SQLite3 作为向量数据库"
echo "   - 使用 OpenAI text-embedding-3-small 模型"
echo ""
echo "🔍 验证:"
echo "   查看日志确认没有 Chroma 错误:"
echo "   tail -f ~/.claude-mem/logs/worker-$(date +%Y-%m-%d).log | grep -i chroma"
echo ""
