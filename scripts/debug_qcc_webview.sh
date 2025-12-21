#!/bin/bash
set -e

DEVICE="emulator-5554"
LOG_FILE="/tmp/flutter_logs.log"

echo "=== 企查查 WebView 调试脚本 ==="

echo "1. 确保 Flutter 应用在前台..."
adb -s $DEVICE shell am start -n cn.cordys.cordyscrm_flutter/.MainActivity
sleep 2

echo "2. 清空日志文件..."
> $LOG_FILE

echo "3. 启动日志监控（后台）..."
adb -s $DEVICE logcat -c
adb -s $DEVICE logcat -v time | grep -E "flutter|QCC|WebView" >> $LOG_FILE 2>&1 &
LOGCAT_PID=$!

echo "4. 等待用户操作..."
echo "   请在 Flutter 应用中："
echo "   - 进入企业搜索页面"
echo "   - 搜索一个关键词（如 alibaba）"
echo "   - 等待 WebView 加载完成"
echo ""
echo "按 Enter 键查看日志..."
read

echo "5. 显示最新日志..."
tail -50 $LOG_FILE

echo ""
echo "6. 停止日志监控..."
kill $LOGCAT_PID 2>/dev/null || true

echo "=== 调试完成 ==="
