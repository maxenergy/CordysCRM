#!/bin/bash
# 启动后端和 Flutter Android 进行联调测试
# 用法: ./scripts/start_backend_and_flutter.sh

set -e

echo "=== 启动后端服务 ==="
cd backend/app
mvn spring-boot:run -Dspring-boot.run.profiles=dev &
BACKEND_PID=$!
cd ../..

echo "后端服务已启动 (PID: $BACKEND_PID)"
echo "等待后端服务启动..."
sleep 10

echo ""
echo "=== 检查 Android 设备 ==="
cd mobile/cordyscrm_flutter

# 检查是否有 Android 设备
if ! flutter devices | grep -q "android"; then
    echo "未检测到 Android 设备，启动模拟器..."
    flutter emulators --launch Fast_Phone_API36 &
    EMULATOR_PID=$!
    echo "等待模拟器启动..."
    sleep 30
fi

echo ""
echo "=== 启动 Flutter Android ==="
flutter run -d android

# 清理
echo ""
echo "=== 清理进程 ==="
kill $BACKEND_PID 2>/dev/null || true
kill $EMULATOR_PID 2>/dev/null || true
