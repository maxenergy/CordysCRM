#!/bin/bash
# 启动 Claude-Mem Worker 服务

set -e

KIRO_MEM_DIR="/home/rogers/source/develop/kiro-mem"
WORKER_SCRIPT="$KIRO_MEM_DIR/claude-mem/plugin/scripts/worker-service.cjs"
LOG_DIR=~/.claude-mem/logs
PID_FILE=~/.claude-mem/worker.pid

# 创建日志目录
mkdir -p "$LOG_DIR"

# 检查服务是否已运行
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        echo "Worker 服务已在运行 (PID: $OLD_PID)"
        exit 0
    fi
fi

# 启动服务
echo "启动 Claude-Mem Worker 服务..."
nohup bun "$WORKER_SCRIPT" > "$LOG_DIR/worker-$(date +%Y-%m-%d).log" 2>&1 &
WORKER_PID=$!

# 保存 PID
echo "$WORKER_PID" > "$PID_FILE"

# 等待服务启动
echo "等待服务启动..."
sleep 3

# 检查服务状态
if curl -s http://127.0.0.1:37777/api/readiness > /dev/null 2>&1; then
    echo "✅ Worker 服务启动成功 (PID: $WORKER_PID)"
    echo "访问 http://127.0.0.1:37777 查看 Web 界面"
else
    echo "❌ Worker 服务启动失败"
    echo "查看日志: tail -f $LOG_DIR/worker-$(date +%Y-%m-%d).log"
    exit 1
fi
