#!/bin/bash
# Flutter 重新编译并运行脚本
# 用法: ./scripts/rebuild_flutter_android.sh

set -e

echo "=========================================="
echo "Flutter 重新编译并运行"
echo "=========================================="

# 获取设备 ID
DEVICE_ID=$(adb devices | grep -w "device" | awk '{print $1}' | head -1)

if [ -z "$DEVICE_ID" ]; then
    echo "错误: 未找到 Android 设备"
    exit 1
fi

echo "设备 ID: $DEVICE_ID"
echo ""

# 进入 Flutter 项目目录
cd mobile/cordyscrm_flutter

echo "清理旧的构建..."
flutter clean

echo ""
echo "获取依赖..."
flutter pub get

echo ""
echo "开始编译并运行..."
flutter run -d $DEVICE_ID

echo ""
echo "=========================================="
echo "Flutter 应用已启动"
echo "=========================================="
