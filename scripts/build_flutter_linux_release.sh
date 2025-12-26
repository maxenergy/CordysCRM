#!/bin/bash
# Flutter Linux Release 版本编译和运行脚本
# 用法: ./scripts/build_flutter_linux_release.sh

set -e  # 遇错即停

# 配置区域
FLUTTER_DIR="mobile/cordyscrm_flutter"
BUILD_DIR="build/linux/x64/release/bundle"

echo "=========================================="
echo "Flutter Linux Release 版本编译脚本"
echo "=========================================="
echo "工作目录: $FLUTTER_DIR"
echo ""

# 切换到 Flutter 项目目录
cd "$FLUTTER_DIR"

echo "🔍 运行代码分析..."
flutter analyze

echo ""
echo "🏗️  开始编译 Release 版本..."
echo "这可能需要几分钟时间..."
echo ""

# 编译 Release 版本
flutter build linux --release

echo ""
echo "✅ 编译完成！"
echo ""
echo "📦 可执行文件位置:"
echo "   $BUILD_DIR/cordyscrm_flutter"
echo ""
echo "🚀 启动应用..."
echo ""

# 运行应用
./$BUILD_DIR/cordyscrm_flutter

echo ""
echo "✅ 应用已退出"
