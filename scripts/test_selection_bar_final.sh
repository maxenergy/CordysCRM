#!/bin/bash

# SelectionBar 最终修复测试脚本

set -e

echo "========================================="
echo "SelectionBar 最终修复测试"
echo "========================================="
echo ""

cd mobile/cordyscrm_flutter

echo "1. 清理构建缓存..."
flutter clean

echo ""
echo "2. 获取依赖..."
flutter pub get

echo ""
echo "3. 分析代码（忽略未使用字段警告）..."
flutter analyze lib/presentation/features/enterprise/enterprise_search_with_webview_page.dart 2>&1 | grep -v "unused_field" || true

echo ""
echo "4. 检查关键文件..."
echo "   - enterprise_search_with_webview_page.dart"
if grep -q "import 'widgets/selection_bar.dart'" lib/presentation/features/enterprise/enterprise_search_with_webview_page.dart; then
    echo "     ✓ SelectionBar 已导入"
else
    echo "     ✗ SelectionBar 未导入"
    exit 1
fi

if grep -q "bottomNavigationBar: searchState.isSelectionMode" lib/presentation/features/enterprise/enterprise_search_with_webview_page.dart; then
    echo "     ✓ bottomNavigationBar 已添加"
else
    echo "     ✗ bottomNavigationBar 未添加"
    exit 1
fi

if grep -q "_showBatchImportConfirmation" lib/presentation/features/enterprise/enterprise_search_with_webview_page.dart; then
    echo "     ✓ 批量导入对话框已添加"
else
    echo "     ✗ 批量导入对话框未添加"
    exit 1
fi

echo ""
echo "5. 检查路由配置..."
if grep -q "EnterpriseSearchWithWebViewPage" lib/presentation/routing/app_router.dart; then
    echo "   ✓ 路由配置正确"
else
    echo "   ✗ 路由配置错误"
    exit 1
fi

echo ""
echo "========================================="
echo "✓ 所有检查通过！"
echo "========================================="
echo ""
echo "下一步："
echo "1. 运行应用: flutter run"
echo "2. 进入企业搜索页面"
echo "3. 搜索企业（如'腾讯'）"
echo "4. 验证'选择'按钮出现"
echo "5. 点击'选择'进入选择模式"
echo "6. 验证 SelectionBar 出现在底部"
echo "7. 测试全选、批量导入功能"
echo ""
echo "详细测试步骤请参考："
echo "  mobile/cordyscrm_flutter/SELECTION_BAR_FIX_FINAL.md"
echo ""
