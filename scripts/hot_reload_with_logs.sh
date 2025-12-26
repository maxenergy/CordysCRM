#!/bin/bash
# 热重载并查看选择模式相关日志

echo "=========================================="
echo "热重载 Flutter 应用并监控选择模式日志"
echo "=========================================="

cd mobile/cordyscrm_flutter

echo ""
echo "正在触发热重载..."
echo "r" | flutter attach --debug 2>&1 | grep -E "Enterprise|选择模式|isSelectionMode|handleLongPress|SelectionBar" &

sleep 2

echo ""
echo "=========================================="
echo "热重载已触发，请在应用中测试："
echo "1. 搜索企业"
echo "2. 长按任意企业项"
echo "3. 观察日志输出和底部栏"
echo "=========================================="
echo ""
echo "按 Ctrl+C 停止"

wait
