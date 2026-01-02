#!/bin/bash

# 实时监控企业导入日志
# 同时监控后端和 Flutter 日志

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}企业导入实时监控${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""

# 检查后端
BACKEND_PID=$(pgrep -f "cn.cordys.Application" || echo "")
if [ -z "$BACKEND_PID" ]; then
    echo -e "${RED}✗ 后端未运行${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 后端运行中 (PID: $BACKEND_PID)${NC}"

# 检查 ADB
if adb devices | grep -q "device$"; then
    echo -e "${GREEN}✓ ADB 已连接${NC}"
    HAS_ADB=true
else
    echo -e "${YELLOW}⚠ ADB 未连接${NC}"
    HAS_ADB=false
fi
echo ""

# 创建日志目录
mkdir -p logs
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo -e "${YELLOW}开始监控...${NC}"
echo -e "${CYAN}请在 Flutter 应用中执行企业导入操作${NC}"
echo -e "${CYAN}(单条或批量导入均可)${NC}"
echo ""
echo -e "${BLUE}按 Ctrl+C 停止监控${NC}"
echo ""
echo -e "${CYAN}=========================================${NC}"
echo ""

# 清空 logcat
if [ "$HAS_ADB" = true ]; then
    adb logcat -c 2>/dev/null || true
fi

# 监控函数
monitor_logs() {
    # 后端日志
    tail -f /proc/$BACKEND_PID/fd/1 2>/dev/null | while read line; do
        # 高亮关键信息
        if echo "$line" | grep -q -E "企业|enterprise|import"; then
            echo -e "${GREEN}[BACKEND]${NC} $line"
        elif echo "$line" | grep -q -E "Exception|Error|失败"; then
            echo -e "${RED}[BACKEND ERROR]${NC} $line"
        elif echo "$line" | grep -q "Caused by:"; then
            echo -e "${YELLOW}[BACKEND CAUSE]${NC} $line"
        elif echo "$line" | grep -q -E "### SQL:|### Parameters:"; then
            echo -e "${BLUE}[BACKEND SQL]${NC} $line"
        elif echo "$line" | grep -q -E "准备插入|插入.*成功|插入.*失败|hasStatement"; then
            echo -e "${CYAN}[BACKEND DEBUG]${NC} $line"
        fi
    done &
    BACKEND_MONITOR_PID=$!
    
    # Flutter logcat
    if [ "$HAS_ADB" = true ]; then
        adb logcat -v time 2>/dev/null | while read line; do
            if echo "$line" | grep -q -E "cordyscrm|enterprise|import|batch"; then
                echo -e "${GREEN}[FLUTTER]${NC} $line"
            elif echo "$line" | grep -q -E "error|exception|失败"; then
                echo -e "${RED}[FLUTTER ERROR]${NC} $line"
            fi
        done &
        FLUTTER_MONITOR_PID=$!
    fi
    
    # 等待中断
    wait
}

# 清理函数
cleanup() {
    echo ""
    echo -e "${YELLOW}停止监控...${NC}"
    kill $BACKEND_MONITOR_PID 2>/dev/null || true
    [ -n "$FLUTTER_MONITOR_PID" ] && kill $FLUTTER_MONITOR_PID 2>/dev/null || true
    echo -e "${GREEN}监控已停止${NC}"
}

trap cleanup EXIT INT TERM

# 开始监控
monitor_logs
