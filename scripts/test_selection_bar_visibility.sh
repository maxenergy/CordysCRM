#!/bin/bash

# 测试 SelectionBar 可见性修复
# 用于验证企业搜索页面进入选择模式后，底部 SelectionBar 是否正确显示

set -e

echo "========================================="
echo "测试 SelectionBar 可见性"
echo "========================================="
echo ""

# 检查 Flutter 环境
if ! command -v flutter &> /dev/null; then
    echo "错误: 未找到 Flutter 命令"
    exit 1
fi

cd mobile/cordyscrm_flutter

echo "1. 运行 Flutter 分析..."
flutter analyze lib/presentation/features/enterprise/enterprise_search_page.dart \
    lib/presentation/features/enterprise/widgets/selection_bar.dart \
    lib/presentation/features/enterprise/enterprise_provider.dart

echo ""
echo "2. 检查关键代码..."

# 检查 bottomNavigationBar 是否正确设置
if grep -q "bottomNavigationBar: searchState.isSelectionMode" lib/presentation/features/enterprise/enterprise_search_page.dart; then
    echo "✓ bottomNavigationBar 条件判断正确"
else
    echo "✗ bottomNavigationBar 条件判断有问题"
    exit 1
fi

# 检查 SelectionBar 是否有 SafeArea
if grep -q "SafeArea" lib/presentation/features/enterprise/widgets/selection_bar.dart; then
    echo "✓ SelectionBar 包含 SafeArea"
else
    echo "✗ SelectionBar 缺少 SafeArea"
    exit 1
fi

# 检查 enterSelectionMode 方法
if grep -q "void enterSelectionMode" lib/presentation/features/enterprise/enterprise_provider.dart; then
    echo "✓ enterSelectionMode 方法存在"
else
    echo "✗ enterSelectionMode 方法缺失"
    exit 1
fi

echo ""
echo "3. 检查调试日志..."

# 检查是否有足够的调试日志
if grep -q "debugPrint.*bottomNavigationBar" lib/presentation/features/enterprise/enterprise_search_page.dart; then
    echo "✓ 包含 bottomNavigationBar 调试日志"
else
    echo "✗ 缺少 bottomNavigationBar 调试日志"
fi

if grep -q "debugPrint.*SelectionBar.*build" lib/presentation/features/enterprise/widgets/selection_bar.dart; then
    echo "✓ SelectionBar 包含 build 调试日志"
else
    echo "✗ SelectionBar 缺少 build 调试日志"
fi

echo ""
echo "========================================="
echo "测试完成！"
echo "========================================="
echo ""
echo "手动测试步骤:"
echo "1. 启动应用: flutter run"
echo "2. 进入企业搜索页面"
echo "3. 搜索企业（例如：'科技公司'）"
echo "4. 长按任意搜索结果进入选择模式"
echo "5. 检查底部是否出现 SelectionBar"
echo "6. 查看控制台日志，确认:"
echo "   - [企业搜索] isSelectionMode=true"
echo "   - [企业搜索] bottomNavigationBar 是否为 null: false"
echo "   - [SelectionBar] build() 被调用"
echo ""
