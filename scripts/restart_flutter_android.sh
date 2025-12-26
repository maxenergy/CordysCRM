#!/bin/bash
# 重启 Flutter Android 应用并查看日志
# 用法: ./scripts/restart_flutter_android.sh

set -e

DEVICE_ID="d91a2f3"
PACKAGE_NAME="cn.cordys.cordyscrm_flutter"

echo "==> 停止应用..."
adb -s $DEVICE_ID shell "am force-stop $PACKAGE_NAME" || true

echo "==> 启动应用..."
adb -s $DEVICE_ID shell "am start -n $PACKAGE_NAME/.MainActivity"

echo "==> 等待应用启动..."
sleep 2

echo "==> 查看日志 (Ctrl+C 退出)..."
adb -s $DEVICE_ID logcat -s flutter:I
