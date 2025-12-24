#!/bin/bash
# Flutter 桌面应用运行脚本
# 用法: ./scripts/run_flutter_desktop.sh [platform]
# platform: linux (默认), windows, macos

set -e  # 遇错即停

# 配置区域
FLUTTER_DIR="mobile/cordyscrm_flutter"
DEFAULT_PLATFORM="linux"

# 获取平台参数
PLATFORM="${1:-$DEFAULT_PLATFORM}"

echo "=========================================="
echo "Flutter 桌面应用编译运行脚本"
echo "=========================================="
echo "平台: $PLATFORM"
echo "工作目录: $FLUTTER_DIR"
echo ""

# 切换到 Flutter 项目目录
cd "$FLUTTER_DIR"

# 检查可用设备
echo "📱 检查可用设备..."
flutter devices

echo ""
echo "🔍 运行代码分析..."
flutter analyze

echo ""
echo "🏗️  开始编译并运行应用..."
echo "平台: $PLATFORM"
echo ""

# 根据平台运行
case "$PLATFORM" in
  linux)
    echo "🐧 在 Linux 平台运行..."
    flutter run -d linux
    ;;
  windows)
    echo "🪟 在 Windows 平台运行..."
    flutter run -d windows
    ;;
  macos)
    echo "🍎 在 macOS 平台运行..."
    flutter run -d macos
    ;;
  *)
    echo "❌ 错误: 不支持的平台 '$PLATFORM'"
    echo "支持的平台: linux, windows, macos"
    exit 1
    ;;
esac

echo ""
echo "✅ 应用已启动"
