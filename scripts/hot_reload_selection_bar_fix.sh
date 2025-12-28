#!/bin/bash
# 热重载 SelectionBar UI 修复
# 用法: ./scripts/hot_reload_selection_bar_fix.sh

set -e

echo "=========================================="
echo "热重载 SelectionBar UI 修复"
echo "=========================================="
echo ""

# 检查 Flutter 进程是否在运行
if ! pgrep -f "flutter run" > /dev/null; then
    echo "❌ Flutter 应用未运行"
    echo "请先运行: flutter run -d <device_id>"
    exit 1
fi

echo "✓ 检测到 Flutter 应用正在运行"
echo ""

# 触发热重载
echo "正在触发热重载..."
echo "r" | nc localhost 43983 2>/dev/null || {
    echo "⚠️  无法通过 VM Service 触发热重载"
    echo "请在 Flutter 终端手动按 'r' 键进行热重载"
}

echo ""
echo "=========================================="
echo "修复内容："
echo "=========================================="
echo "1. ✅ 优化导入进度对话框宽度"
echo "2. ✅ 美化导入结果显示（成功/失败统计卡片）"
echo "3. ✅ 简化错误信息显示（提取关键信息）"
echo "4. ✅ 优化 SelectionBar 样式："
echo "   - 增加高度到 64px"
echo "   - 为全选区域添加边框"
echo "   - 优化按钮间距和大小"
echo "   - 改进阴影效果"
echo ""
echo "=========================================="
echo "测试步骤："
echo "=========================================="
echo "1. 进入企业查询页面"
echo "2. 长按任意企业进入选择模式"
echo "3. 查看底部 SelectionBar 样式是否改善"
echo "4. 选择多个企业"
echo "5. 点击'批量导入'按钮"
echo "6. 查看导入进度对话框样式"
echo "7. 查看导入完成对话框样式"
echo ""
echo "=========================================="
echo "已知修复："
echo "=========================================="
echo "✓ 导入进度对话框现在有固定宽度"
echo "✓ 错误信息现在更简洁易读"
echo "✓ 成功/失败统计使用卡片样式"
echo "✓ SelectionBar 按钮和复选框更美观"
echo "✓ 图标使用 Material Icons（无需额外资源）"
echo ""
