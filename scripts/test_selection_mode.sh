#!/bin/bash
# 测试选择模式和全选功能

echo "=========================================="
echo "测试选择模式和全选功能"
echo "=========================================="

cd mobile/cordyscrm_flutter

echo ""
echo "步骤 1: 执行热重载..."
flutter attach --debug 2>&1 | grep -E "\[Enterprise|选择模式|isSelectionMode|handleLongPress" &

FLUTTER_PID=$!

echo ""
echo "Flutter 日志监控已启动 (PID: $FLUTTER_PID)"
echo ""
echo "=========================================="
echo "测试步骤："
echo "1. 在企业搜索页面搜索企业"
echo "2. 长按任意企业项"
echo "3. 观察是否进入选择模式（底部应出现全选栏）"
echo "4. 点击全选checkbox"
echo "5. 点击批量导入按钮"
echo "=========================================="
echo ""
echo "按 Ctrl+C 停止日志监控"

wait $FLUTTER_PID
