#!/bin/bash

# Flutter 企业导入实时监控脚本
# 监控 Flutter logcat 和后端日志，捕获完整错误堆栈

set -e

echo "========================================="
echo "Flutter 企业导入实时监控"
echo "========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 创建日志目录
mkdir -p logs
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="logs/flutter_import_monitor_${TIMESTAMP}.log"

echo -e "${GREEN}✓ 日志将保存到: $LOG_FILE${NC}"
echo ""

# 检查 ADB
if ! adb devices | grep -q "device$"; then
    echo -e "${RED}✗ ADB 设备未连接${NC}"
    exit 1
fi
echo -e "${GREEN}✓ ADB 设备已连接${NC}"

# 检查后端
BACKEND_PID=$(pgrep -f "cn.cordys.Application" || echo "")
if [ -z "$BACKEND_PID" ]; then
    echo -e "${RED}✗ 后端未运行${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 后端正在运行 (PID: $BACKEND_PID)${NC}"
echo ""

# 清空 logcat
echo -e "${YELLOW}清空 logcat 缓冲区...${NC}"
adb logcat -c
echo ""

echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}开始监控（按 Ctrl+C 停止）${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""
echo -e "${YELLOW}请在 Flutter 应用中执行企业导入操作...${NC}"
echo -e "${YELLOW}（单条或批量导入均可）${NC}"
echo ""

# 同时监控 Flutter 和后端日志
{
    echo "=== 监控开始时间: $(date) ===" 
    echo ""
    
    # Flutter logcat（后台）
    adb logcat -v time | grep --line-buffered -E "cordyscrm|flutter|enterprise|import|batch|error|exception" &
    LOGCAT_PID=$!
    
    # 后端日志（后台）
    tail -f /proc/$BACKEND_PID/fd/1 2>/dev/null | grep --line-buffered -E "企业|enterprise|import|MyBatis|SQL|Exception|Error|Caused by|insertWithDateConversion|准备插入|插入.*成功|插入.*失败" &
    BACKEND_LOG_PID=$!
    
    # 等待用户中断
    trap "echo ''; echo -e '${YELLOW}停止监控...${NC}'; kill $LOGCAT_PID $BACKEND_LOG_PID 2>/dev/null; exit 0" INT TERM
    
    wait
} 2>&1 | tee "$LOG_FILE"

