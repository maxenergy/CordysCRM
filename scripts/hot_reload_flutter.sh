#!/bin/bash
# Flutter 热重载脚本
# 用法: ./scripts/hot_reload_flutter.sh

set -e

echo "=========================================="
echo "Flutter 热重载"
echo "=========================================="

# 获取设备 ID
DEVICE_ID=$(adb devices | grep -w "device" | awk '{print $1}' | head -1)

if [ -z "$DEVICE_ID" ]; then
    echo "错误: 未找到 Android 设备"
    exit 1
fi

echo "设备 ID: $DEVICE_ID"

# 获取 Flutter 进程 PID
FLUTTER_PID=$(ps aux | grep "flutter run" | grep -v grep | awk '{print $2}' | head -1)

if [ -z "$FLUTTER_PID" ]; then
    echo "错误: Flutter 进程未运行"
    exit 1
fi

echo "Flutter PID: $FLUTTER_PID"
echo ""
echo "发送热重载信号..."

# 发送 'r' 命令到 Flutter 进程进行热重载
echo "r" > /proc/$FLUTTER_PID/fd/0 2>/dev/null || {
    echo "警告: 无法直接发送热重载命令"
    echo "请在 Flutter 终端手动按 'r' 键进行热重载"
}

echo ""
echo "=========================================="
echo "热重载完成"
echo "=========================================="
