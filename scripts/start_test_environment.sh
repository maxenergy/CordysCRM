#!/bin/bash
# 启动测试环境：后端 + Flutter Android
# 用法: ./scripts/start_test_environment.sh

set -e

echo "=========================================="
echo "启动测试环境"
echo "=========================================="
echo ""

# 检查是否已有后端进程在运行
if pgrep -f "spring-boot:run" > /dev/null; then
    echo "⚠️  后端服务已在运行"
else
    echo "1. 启动后端服务..."
    cd backend/app
    nohup mvn spring-boot:run -Dspring-boot.run.profiles=dev > ../../logs/backend.log 2>&1 &
    BACKEND_PID=$!
    echo "   后端服务已启动 (PID: $BACKEND_PID)"
    echo "   日志文件: logs/backend.log"
    cd ../..
    
    echo "   等待后端服务启动..."
    sleep 15
fi

echo ""
echo "2. 检查 Android 设备..."
cd mobile/cordyscrm_flutter

# 检查是否有 Android 设备
DEVICE_COUNT=$(flutter devices 2>/dev/null | grep -c "android" || echo "0")

if [ "$DEVICE_COUNT" -eq "0" ]; then
    echo "   未检测到 Android 设备"
    echo "   请手动连接设备或启动模拟器"
    echo ""
    echo "   可用的模拟器："
    flutter emulators
    echo ""
    read -p "   是否启动模拟器？(y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "   启动模拟器..."
        flutter emulators --launch Fast_Phone_API36 &
        echo "   等待模拟器启动..."
        sleep 30
    else
        echo "   已取消"
        exit 1
    fi
else
    echo "   检测到 $DEVICE_COUNT 个 Android 设备"
    flutter devices | grep "android"
fi

echo ""
echo "3. 启动 Flutter Android..."
echo "   正在编译和安装..."
flutter run -d android

cd ../..
