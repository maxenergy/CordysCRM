#!/bin/bash
# 调试长按手势问题
# 用法: ./scripts/debug_long_press.sh

set -e

DEVICE_ID="d91a2f3"
FLUTTER_DIR="mobile/cordyscrm_flutter"

echo "=========================================="
echo "调试长按手势问题"
echo "=========================================="

cd "$FLUTTER_DIR"

echo ""
echo "1. 停止现有的 Flutter 应用..."
flutter run -d "$DEVICE_ID" --stop || true

echo ""
echo "2. 热重启 Flutter 应用..."
flutter run -d "$DEVICE_ID" &
FLUTTER_PID=$!

echo ""
echo "Flutter 应用已启动 (PID: $FLUTTER_PID)"
echo ""
echo "=========================================="
echo "请在设备上执行以下操作："
echo "1. 打开企业搜索页面"
echo "2. 搜索企业（例如：腾讯）"
echo "3. 长按搜索结果中的企业项（按住1-2秒）"
echo "=========================================="
echo ""
echo "监控日志输出（查找以下关键词）："
echo "  - [Item Build]"
echo "  - [Item] GestureDetector 长按触发"
echo "  - [Page] 长按回调被调用"
echo "  - [选择模式]"
echo "  - Gesture arena"
echo ""
echo "按 Ctrl+C 停止监控"
echo ""

# 等待 Flutter 进程
wait $FLUTTER_PID
