#!/bin/bash
# 重启 Flutter 应用（应用长按修复）
# 用法: ./scripts/restart_flutter_with_fix.sh

set -e

echo "=========================================="
echo "重启 Flutter 应用（长按修复版本）"
echo "=========================================="
echo ""

# 获取设备 ID
DEVICE_ID=$(adb devices | grep -w "device" | awk '{print $1}' | head -1)

if [ -z "$DEVICE_ID" ]; then
    echo "错误: 未找到 Android 设备"
    echo "请确保设备已通过 USB 连接并启用 USB 调试"
    exit 1
fi

echo "✓ 设备 ID: $DEVICE_ID"
echo ""

# 停止现有的 Flutter 应用
echo "停止现有的 Flutter 应用..."
adb -s $DEVICE_ID shell am force-stop cn.cordys.crm 2>/dev/null || true
sleep 1

# 检查后端是否运行
echo ""
echo "检查后端服务..."
BACKEND_PID=$(ps aux | grep "Application" | grep "backend/app" | grep -v grep | awk '{print $2}' | head -1)

if [ -z "$BACKEND_PID" ]; then
    echo "⚠ 后端未运行，正在启动..."
    echo ""
    echo "启动后端服务..."
    nohup mvn spring-boot:run -f backend/app/pom.xml > /tmp/backend.log 2>&1 &
    BACKEND_PID=$!
    echo "✓ 后端 PID: $BACKEND_PID"
    echo "  等待后端启动..."
    sleep 10
else
    echo "✓ 后端已运行 (PID: $BACKEND_PID)"
fi

echo ""
echo "=========================================="
echo "重新编译并启动 Flutter 应用"
echo "=========================================="
echo ""

# 进入 Flutter 目录并运行
cd mobile/cordyscrm_flutter

# 清理构建缓存
echo "清理构建缓存..."
flutter clean > /dev/null 2>&1

# 获取依赖
echo "获取依赖..."
flutter pub get > /dev/null 2>&1

echo ""
echo "编译并安装到设备..."
echo "（这可能需要 1-2 分钟）"
echo ""

# 运行 Flutter 应用
flutter run -d $DEVICE_ID --release 2>&1 | tee /tmp/flutter.log &
FLUTTER_PID=$!

echo ""
echo "=========================================="
echo "Flutter 应用已启动"
echo "=========================================="
echo ""
echo "✓ Flutter PID: $FLUTTER_PID"
echo "✓ 后端 PID: $BACKEND_PID"
echo "✓ 设备 ID: $DEVICE_ID"
echo ""
echo "后端日志: tail -f /tmp/backend.log"
echo "Flutter 日志: tail -f /tmp/flutter.log"
echo ""
echo "=========================================="
echo "测试步骤："
echo "=========================================="
echo "1. 在设备上打开企业搜索页面"
echo "2. 搜索企业（例如：激光）"
echo "3. 长按搜索结果中的企业项（按住1-2秒）"
echo "4. 观察是否进入选择模式（显示复选框和底部操作栏）"
echo ""
echo "=========================================="
echo "监控日志："
echo "=========================================="
echo "# 在另一个终端运行："
echo "./scripts/monitor_long_press.sh"
echo ""
echo "按 Ctrl+C 停止"
echo "=========================================="

# 等待用户中断
wait $FLUTTER_PID
