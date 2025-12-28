#!/bin/bash

# 测试 SelectionBar 显示修复
# 此脚本用于验证企业搜索界面的选择模式底部栏是否正确显示

set -e

echo "========================================="
echo "测试 SelectionBar 显示修复"
echo "========================================="
echo ""

# 检查 Flutter 环境
if ! command -v flutter &> /dev/null; then
    echo "错误: 未找到 Flutter 命令"
    exit 1
fi

# 进入 Flutter 项目目录
cd mobile/cordyscrm_flutter

echo "1. 运行 Flutter 分析..."
flutter analyze lib/presentation/features/enterprise/widgets/selection_bar.dart
echo "✓ 代码分析通过"
echo ""

echo "2. 检查关键文件..."
files=(
    "lib/presentation/features/enterprise/enterprise_search_page.dart"
    "lib/presentation/features/enterprise/widgets/selection_bar.dart"
    "lib/presentation/features/enterprise/enterprise_provider.dart"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "✓ $file 存在"
    else
        echo "✗ $file 不存在"
        exit 1
    fi
done
echo ""

echo "3. 验证 SelectionBar 布局修复..."
if grep -q "Material(" lib/presentation/features/enterprise/widgets/selection_bar.dart; then
    echo "✓ SelectionBar 使用 Material widget 包裹"
else
    echo "✗ SelectionBar 未使用 Material widget"
    exit 1
fi

if grep -q "elevation: 8" lib/presentation/features/enterprise/widgets/selection_bar.dart; then
    echo "✓ SelectionBar 设置了 elevation"
else
    echo "✗ SelectionBar 未设置 elevation"
    exit 1
fi

if grep -q "height: 60" lib/presentation/features/enterprise/widgets/selection_bar.dart; then
    echo "✓ SelectionBar 设置了固定高度"
else
    echo "✗ SelectionBar 未设置固定高度"
    exit 1
fi
echo ""

echo "4. 验证选择模式逻辑..."
if grep -q "isSelectionMode" lib/presentation/features/enterprise/enterprise_search_page.dart; then
    echo "✓ 企业搜索页面包含选择模式逻辑"
else
    echo "✗ 企业搜索页面缺少选择模式逻辑"
    exit 1
fi

if grep -q "bottomNavigationBar: searchState.isSelectionMode" lib/presentation/features/enterprise/enterprise_search_page.dart; then
    echo "✓ bottomNavigationBar 根据选择模式条件渲染"
else
    echo "✗ bottomNavigationBar 条件渲染逻辑有误"
    exit 1
fi
echo ""

echo "========================================="
echo "✓ 所有检查通过！"
echo "========================================="
echo ""
echo "修复说明:"
echo "1. SelectionBar 现在使用 Material widget 包裹，提供正确的 elevation"
echo "2. 使用 Container 设置固定高度和 padding，确保布局稳定"
echo "3. SafeArea 设置 top: false，避免顶部内边距影响底部栏"
echo ""
echo "测试步骤:"
echo "1. 运行 Flutter 应用: flutter run"
echo "2. 进入企业搜索页面"
echo "3. 搜索企业（例如：'科技公司'）"
echo "4. 长按任意企业项进入选择模式"
echo "5. 验证底部是否出现 SelectionBar（包含取消、全选、批量导入按钮）"
echo ""
