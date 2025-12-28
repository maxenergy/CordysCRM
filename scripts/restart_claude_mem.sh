#!/bin/bash
# 重启 Claude-Mem Worker 服务

echo "正在重启 Claude-Mem Worker 服务..."

# 检查是否有 bun
if ! command -v bun &> /dev/null; then
    echo "❌ 错误: 未找到 bun 命令"
    echo "请先安装 bun: https://bun.sh"
    exit 1
fi

# 查找 worker-cli.js
WORKER_CLI="/home/rogers/source/develop/kiro-mem/claude-mem/plugin/scripts/worker-cli.js"

if [ ! -f "$WORKER_CLI" ]; then
    echo "❌ 错误: 未找到 worker-cli.js at $WORKER_CLI"
    echo "请确保 claude-mem 已正确安装"
    exit 1
fi

echo "找到 worker-cli: $WORKER_CLI"

# 停止服务
echo "1. 停止现有服务..."
bun "$WORKER_CLI" stop

sleep 2

# 启动服务
echo "2. 启动服务..."
bun "$WORKER_CLI" start

sleep 2

# 检查状态
echo "3. 检查服务状态..."
bun "$WORKER_CLI" status

echo ""
echo "✅ 重启完成"
echo ""
echo "请在 Kiro IDE 中重新连接 claude-mem MCP 服务器"
