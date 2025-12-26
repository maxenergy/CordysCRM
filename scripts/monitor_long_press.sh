#!/bin/bash
# 监控长按手势日志
# 用法: ./scripts/monitor_long_press.sh

echo "=========================================="
echo "监控长按手势日志"
echo "=========================================="
echo ""
echo "请在设备上执行以下操作："
echo "1. 打开企业搜索页面"
echo "2. 搜索企业（例如：腾讯）"
echo "3. 长按搜索结果中的企业项（按住1-2秒）"
echo ""
echo "=========================================="
echo "关键日志标识："
echo "=========================================="
echo "[Item Build] - 列表项构建"
echo "[Item] GestureDetector 长按触发 - 长按手势被触发"
echo "[Page] 长按回调被调用 - 页面接收到长按回调"
echo "[选择模式] - 选择模式状态变化"
echo "Gesture arena - 手势竞争诊断"
echo ""
echo "=========================================="
echo "开始监控..."
echo "=========================================="
echo ""

# 监控 Flutter 日志
adb logcat -s flutter:I | grep -E '\[Item\]|\[Page\]|\[选择模式\]|Gesture arena|GestureDetector'
