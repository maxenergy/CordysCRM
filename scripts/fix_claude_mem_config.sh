#!/bin/bash
# 修复 Claude-Mem MCP 配置

CURRENT_PROJECT=$(pwd)
MCP_CONFIG=~/.kiro/settings/mcp.json

echo "=== 修复 Claude-Mem MCP 配置 ==="
echo ""
echo "当前项目路径: $CURRENT_PROJECT"
echo "MCP 配置文件: $MCP_CONFIG"
echo ""

# 备份原配置
echo "1. 备份原配置..."
cp "$MCP_CONFIG" "$MCP_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
echo "   ✅ 备份完成"
echo ""

# 更新配置
echo "2. 更新 claude-mem 配置..."
cat "$MCP_CONFIG" | jq \
  --arg project "$CURRENT_PROJECT" \
  '.mcpServers["claude-mem"].env.CLAUDE_MEM_SOURCE_PROJECT = $project' \
  > "$MCP_CONFIG.tmp" && mv "$MCP_CONFIG.tmp" "$MCP_CONFIG"

echo "   ✅ 配置已更新"
echo ""

# 显示新配置
echo "3. 新的 claude-mem 配置:"
cat "$MCP_CONFIG" | jq '.mcpServers["claude-mem"]'
echo ""

echo "=== 修复完成 ==="
echo ""
echo "下一步操作:"
echo "1. 在 Kiro IDE 中重新连接 claude-mem MCP 服务器"
echo "2. 或者重启 Kiro IDE"
echo "3. 使用一些工具（如 readFile）后，claude-mem 应该开始捕获观察"
