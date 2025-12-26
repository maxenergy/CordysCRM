#!/bin/bash
# 测试批量导入 UI 功能
# 用法: ./scripts/test_batch_import_ui.sh

set -e

echo "=========================================="
echo "批量导入 UI 功能测试"
echo "=========================================="
echo ""

echo "1. 检查 Flutter 环境..."
flutter --version

echo ""
echo "2. 编译 Flutter 应用..."
cd mobile/cordyscrm_flutter
flutter build apk --debug

echo ""
echo "3. 安装到设备..."
flutter install

echo ""
echo "=========================================="
echo "测试步骤："
echo "=========================================="
echo ""
echo "1. 打开应用，进入企业搜索页面"
echo "2. 搜索企业（例如：激光）"
echo "3. 查看搜索结果"
echo ""
echo "【测试点 1】AppBar 右上角应该显示"选择"按钮"
echo "   - 点击"选择"按钮"
echo "   - 应该进入选择模式"
echo "   - 每个企业项左侧应该显示勾选框"
echo "   - 底部应该显示选择栏（取消、全选、批量导入）"
echo ""
echo "【测试点 2】全选功能"
echo "   - 点击底部的"全选"复选框"
echo "   - 所有非本地企业应该被选中"
echo "   - 再次点击应该取消全选"
echo ""
echo "【测试点 3】批量导入功能"
echo "   - 选择几个企业"
echo "   - 点击"批量导入"按钮"
echo "   - 应该显示确认对话框"
echo "   - 确认后应该显示导入进度"
echo "   - 导入完成后应该显示结果摘要"
echo ""
echo "【测试点 4】长按快捷方式"
echo "   - 退出选择模式"
echo "   - 长按某个企业项"
echo "   - 应该进入选择模式并预选该企业"
echo ""
echo "【测试点 5】取消选择"
echo "   - 点击底部的"取消"按钮"
echo "   - 应该退出选择模式"
echo "   - 勾选框应该消失"
echo "   - 底部选择栏应该消失"
echo ""
echo "=========================================="
echo "测试完成！"
echo "=========================================="
