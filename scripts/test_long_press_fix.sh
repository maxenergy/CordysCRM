#!/bin/bash
# 测试长按手势修复
# 用法: ./scripts/test_long_press_fix.sh

set -e

# 自动检测 Android 设备
DEVICE_ID=$(adb devices | grep -w "device" | awk '{print $1}' | head -1)
if [ -z "$DEVICE_ID" ]; then
    echo "错误: 未检测到 Android 设备"
    echo "请确保设备已通过 USB 连接并启用 USB 调试"
    exit 1
fi

echo "检测到设备: $DEVICE_ID"
FLUTTER_DIR="mobile/cordyscrm_flutter"

echo "=========================================="
echo "测试长按手势修复"
echo "=========================================="

# 1. 启动后端
echo ""
echo "1. 启动后端服务..."
cd backend/app
mvn spring-boot:run > /tmp/backend.log 2>&1 &
BACKEND_PID=$!
echo "后端已启动 (PID: $BACKEND_PID)"
cd ../..

# 等待后端启动
echo "等待后端启动（20秒）..."
sleep 20

# 检查后端是否真的启动了
echo "检查后端状态..."
if curl -s http://localhost:8081/actuator/health > /dev/null 2>&1; then
    echo "✓ 后端已成功启动"
else
    echo "✗ 后端启动失败，请查看日志: tail -f /tmp/backend.log"
    exit 1
fi

# 2. 启动 Flutter
echo ""
echo "2. 启动 Flutter 应用..."
cd "$FLUTTER_DIR"

# 热重启（如果已运行）或重新运行
flutter run -d "$DEVICE_ID" > /tmp/flutter.log 2>&1 &
FLUTTER_PID=$!
echo "Flutter 应用已启动 (PID: $FLUTTER_PID)"
cd ../..

echo ""
echo "=========================================="
echo "服务已启动"
echo "=========================================="
echo "后端 PID: $BACKEND_PID (端口 8081)"
echo "Flutter PID: $FLUTTER_PID"
echo ""
echo "后端日志: tail -f /tmp/backend.log"
echo "Flutter 日志: tail -f /tmp/flutter.log"
echo ""
echo "=========================================="
echo "测试步骤："
echo "=========================================="
echo "1. 在设备上打开企业搜索页面"
echo "2. 搜索企业（例如：腾讯）"
echo "3. 长按搜索结果中的企业项（按住1-2秒）"
echo "4. 观察是否进入选择模式（显示复选框和底部操作栏）"
echo ""
echo "=========================================="
echo "监控关键日志："
echo "=========================================="
echo ""
echo "# 监控 Flutter 日志（新终端）："
echo "adb logcat -s flutter:I | grep -E '\[Item\]|\[Page\]|\[选择模式\]|Gesture arena'"
echo ""
echo "=========================================="
echo "修复说明："
echo "=========================================="
echo "1. 将 InkWell 替换为 GestureDetector"
echo "2. 添加 behavior: HitTestBehavior.opaque"
echo "3. 启用手势竞争诊断 (debugPrintGestureArenaDiagnostics)"
echo ""
echo "如果长按仍无效，请查看日志中的 'Gesture arena' 信息"
echo "判断是否有其他手势识别器拦截了长按事件"
echo ""
echo "按 Ctrl+C 停止所有服务"
echo ""

# 等待用户中断
trap "echo ''; echo '停止服务...'; kill $BACKEND_PID $FLUTTER_PID 2>/dev/null; exit 0" INT

# 保持脚本运行
wait
