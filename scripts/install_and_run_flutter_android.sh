#!/bin/bash
# 安装并运行 Flutter Android 应用到 USB 设备
# 用法: ./scripts/install_and_run_flutter_android.sh

set -e

echo "=== 检查 Android 设备 ==="
adb devices -l

echo ""
echo "=== 检查后端服务状态 ==="
if curl -s http://localhost:8081/actuator/health > /dev/null 2>&1; then
    echo "✓ 后端服务运行正常 (http://localhost:8081)"
else
    echo "✗ 后端服务未运行，请先启动后端"
    echo "  运行: cd backend/app && mvn spring-boot:run -Dspring-boot.run.profiles=dev"
    exit 1
fi

echo ""
echo "=== 构建并安装 Flutter 应用 ==="
cd mobile/cordyscrm_flutter

# 获取设备 ID
DEVICE_ID=$(adb devices | grep -w "device" | awk '{print $1}' | head -1)

if [ -z "$DEVICE_ID" ]; then
    echo "✗ 未检测到 Android 设备"
    exit 1
fi

echo "目标设备: $DEVICE_ID"
echo ""

# 安装并运行
flutter run -d "$DEVICE_ID" --verbose

cd ../..
