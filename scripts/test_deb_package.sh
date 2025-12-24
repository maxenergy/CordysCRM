#!/bin/bash
# DEB 包测试脚本（仅显示信息，不实际安装）
# 用法: ./scripts/test_deb_package.sh

set -e

DEB_FILE="build/deb-package/cordyscrm-flutter_1.0.0_amd64.deb"

echo "=========================================="
echo "DEB 包测试脚本"
echo "=========================================="
echo ""

# 检查 DEB 文件是否存在
if [ ! -f "$DEB_FILE" ]; then
    echo "❌ 错误: DEB 包不存在"
    echo "请先运行: ./scripts/package_flutter_linux_deb.sh"
    exit 1
fi

echo "✅ DEB 包文件存在"
echo ""

# 显示包信息
echo "📋 包信息:"
echo "----------------------------------------"
dpkg-deb --info "$DEB_FILE"
echo ""

# 显示包大小
echo "📊 包大小:"
echo "----------------------------------------"
du -h "$DEB_FILE"
echo ""

# 显示包内容（前 30 行）
echo "📂 包内容（前 30 项）:"
echo "----------------------------------------"
dpkg-deb --contents "$DEB_FILE" | head -30
echo ""

# 检查依赖是否已安装
echo "🔍 检查系统依赖:"
echo "----------------------------------------"

DEPS=("libgtk-3-0" "libglib2.0-0" "libgdk-pixbuf2.0-0" "libcairo2" "libpango-1.0-0")
ALL_DEPS_OK=true

for dep in "${DEPS[@]}"; do
    if dpkg -l | grep -q "^ii  $dep"; then
        echo "✅ $dep - 已安装"
    else
        echo "❌ $dep - 未安装"
        ALL_DEPS_OK=false
    fi
done

echo ""

if [ "$ALL_DEPS_OK" = true ]; then
    echo "✅ 所有依赖都已安装"
else
    echo "⚠️  部分依赖未安装"
    echo ""
    echo "安装缺失的依赖:"
    echo "  sudo apt-get install -f"
fi

echo ""
echo "=========================================="
echo "测试完成"
echo "=========================================="
echo ""
echo "📝 安装说明:"
echo ""
echo "1. 安装包:"
echo "   sudo dpkg -i $DEB_FILE"
echo ""
echo "2. 如果遇到依赖问题:"
echo "   sudo apt-get install -f"
echo ""
echo "3. 运行应用:"
echo "   cordyscrm-flutter"
echo ""
echo "4. 卸载:"
echo "   sudo dpkg -r cordyscrm-flutter"
echo ""
echo "⚠️  注意: 此脚本仅显示信息，不会实际安装包"
echo "   如需安装，请手动运行上述命令"
echo ""
