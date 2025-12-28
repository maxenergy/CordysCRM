#!/bin/bash

# 批量导入日期修复测试脚本
# 测试 LocalDate 类型转换是否正确

echo "=========================================="
echo "批量导入日期修复测试"
echo "=========================================="
echo ""

# 检查 backend 是否运行
echo "1. 检查 backend 状态..."
if curl -s http://localhost:8081/actuator/health > /dev/null 2>&1; then
    echo "   ✓ Backend 运行正常"
else
    echo "   ✗ Backend 未运行，请先启动 backend"
    exit 1
fi

# 检查 Flutter 应用是否运行
echo ""
echo "2. 检查 Flutter 应用状态..."
if adb -s d91a2f3 shell pidof cn.cordys.cordyscrm_flutter > /dev/null 2>&1; then
    echo "   ✓ Flutter 应用运行正常"
else
    echo "   ✗ Flutter 应用未运行"
    exit 1
fi

echo ""
echo "=========================================="
echo "测试步骤："
echo "=========================================="
echo "1. 在 Flutter 应用中打开企业搜索页面"
echo "2. 搜索任意企业（例如：腾讯）"
echo "3. 长按选择 3-5 个企业"
echo "4. 点击底部选择栏的「批量导入」按钮"
echo "5. 在确认对话框中点击「确认导入」"
echo ""
echo "预期结果："
echo "- 所有企业应该成功导入（成功数 = 选择数）"
echo "- 不应该出现「Incorrect date value」错误"
echo "- 导入结果对话框显示成功统计"
echo ""
echo "=========================================="
echo "监控 backend 日志："
echo "=========================================="
echo ""

# 实时监控 backend 日志中的错误
echo "正在监控 backend 日志（按 Ctrl+C 停止）..."
echo ""

# 监控进程输出（假设 backend 是 Process 19）
tail -f /opt/cordys/logs/cordys-crm/error.log 2>/dev/null &
TAIL_PID=$!

# 同时监控 Flutter 日志
adb -s d91a2f3 logcat -s flutter:I | grep -E "导入|import|regDate|DATE|Error" &
LOGCAT_PID=$!

# 等待用户中断
trap "kill $TAIL_PID $LOGCAT_PID 2>/dev/null; exit 0" INT

wait
