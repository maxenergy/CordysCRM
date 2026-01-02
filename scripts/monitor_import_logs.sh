#!/bin/bash

# 企业导入实时日志监控脚本
# 同时监控后端日志和 Flutter logcat

set -e

echo "========================================="
echo "企业导入实时日志监控"
echo "========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 创建日志目录
mkdir -p logs

# 生成时间戳
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKEND_LOG="logs/backend_import_${TIMESTAMP}.log"
FLUTTER_LOG="logs/flutter_import_${TIMESTAMP}.log"
COMBINED_LOG="logs/combined_import_${TIMESTAMP}.log"

echo -e "${GREEN}✓ 日志将保存到:${NC}"
echo "  - 后端日志: $BACKEND_LOG"
echo "  - Flutter日志: $FLUTTER_LOG"
echo "  - 合并日志: $COMBINED_LOG"
echo ""

# 检查 ADB 连接
if ! adb devices | grep -q "device$"; then
    echo -e "${RED}✗ ADB 设备未连接${NC}"
    echo "请先连接 Android 设备"
    exit 1
fi

echo -e "${GREEN}✓ ADB 设备已连接${NC}"
echo ""

# 清空 logcat 缓冲区
echo -e "${YELLOW}清空 logcat 缓冲区...${NC}"
adb logcat -c

echo ""
echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}开始监控日志（按 Ctrl+C 停止）${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""
echo -e "${YELLOW}请在 Flutter 应用中执行企业导入操作...${NC}"
echo ""

# 启动后端日志监控（后台）
(
    # 监控后端进程的标准输出
    tail -f /proc/$(pgrep -f "cn.cordys.Application")/fd/1 2>/dev/null | \
    grep --line-buffered -E "企业|enterprise|import|MyBatis|SQL|Exception|Error|Caused by|insertWithDateConversion|hasStatement" | \
    tee -a "$BACKEND_LOG" | \
    while IFS= read -r line; do
        echo -e "${BLUE}[BACKEND]${NC} $line" | tee -a "$COMBINED_LOG"
    done
) &
BACKEND_PID=$!

# 启动 Flutter logcat 监控（后台）
(
    adb logcat | \
    grep --line-buffered -E "cordyscrm|flutter|enterprise|import|batch|MyBatis|SQL|Exception|Error" | \
    tee -a "$FLUTTER_LOG" | \
    while IFS= read -r line; do
        echo -e "${GREEN}[FLUTTER]${NC} $line" | tee -a "$COMBINED_LOG"
    done
) &
FLUTTER_PID=$!

# 等待用户中断
trap "echo ''; echo -e '${YELLOW}停止监控...${NC}'; kill $BACKEND_PID $FLUTTER_PID 2>/dev/null; exit 0" INT TERM

# 保持脚本运行
wait

