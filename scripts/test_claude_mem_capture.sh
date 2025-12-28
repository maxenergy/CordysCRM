#!/bin/bash
# 测试 Claude-Mem 观察捕获功能

set -e

echo "=== 测试 Claude-Mem 观察捕获 ==="
echo ""

# 1. 检查 Worker 状态
echo "1. 检查 Worker 服务..."
if ! curl -s http://localhost:37777/api/readiness | grep -q "ready"; then
    echo "✗ Worker 服务未运行"
    exit 1
fi
echo "✓ Worker 服务运行正常"
echo ""

# 2. 手动创建一个测试观察
echo "2. 手动创建测试观察..."

# 获取当前项目名称
PROJECT_NAME=$(basename $(pwd))

# 创建测试观察数据
TEST_OBSERVATION=$(cat <<EOF
{
  "project": "$PROJECT_NAME",
  "type": "tool_use",
  "title": "Test Observation",
  "subtitle": "Manual test",
  "narrative": "This is a manual test observation to verify Claude-Mem is working",
  "facts": ["Test fact 1", "Test fact 2"],
  "concepts": ["testing", "claude-mem", "observation"],
  "files_read": ["scripts/test_claude_mem_capture.sh"],
  "files_modified": []
}
EOF
)

echo "发送测试观察到 Worker..."
RESPONSE=$(curl -s -X POST http://localhost:37777/api/observations \
  -H "Content-Type: application/json" \
  -d "$TEST_OBSERVATION")

echo "响应: $RESPONSE"
echo ""

# 3. 等待处理
echo "3. 等待观察处理..."
sleep 2
echo ""

# 4. 检查数据库
echo "4. 检查数据库..."
DB_PATH=~/.claude-mem/claude-mem.db
OBS_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM observations;")
echo "   观察记录数: $OBS_COUNT"

if [ "$OBS_COUNT" -gt 0 ]; then
    echo "✓ 观察已成功捕获！"
    echo ""
    echo "最新的观察:"
    sqlite3 "$DB_PATH" "SELECT id, type, title, created_at FROM observations ORDER BY created_at DESC LIMIT 1;"
else
    echo "✗ 观察未被捕获"
fi
echo ""

# 5. 测试搜索
echo "5. 测试搜索功能..."
SEARCH_RESULT=$(curl -s "http://localhost:37777/api/search?query=test&limit=5")
echo "搜索结果:"
echo "$SEARCH_RESULT" | python3 -m json.tool 2>/dev/null || echo "$SEARCH_RESULT"
echo ""

# 6. 检查 Chroma
echo "6. 检查 Chroma 目录..."
if [ -d ~/.claude-mem/chroma ]; then
    echo "✓ Chroma 目录已创建"
    du -sh ~/.claude-mem/chroma
else
    echo "✗ Chroma 目录仍不存在"
fi
echo ""

echo "=== 测试完成 ==="
