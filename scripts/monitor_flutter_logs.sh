#!/bin/bash
# 监控 Flutter 应用日志
# 用法: ./scripts/monitor_flutter_logs.sh

DEVICE_ID="d91a2f3"

echo "==> 监控 Flutter 日志 (Ctrl+C 退出)..."
echo "==> 请在手机上操作：搜索'激光'，然后长按任意企业项"
echo ""

adb -s $DEVICE_ID logcat -s flutter:I | grep -E "\[Page Build\]|\[选择模式\]|\[Item\]|enterSelectionMode"
