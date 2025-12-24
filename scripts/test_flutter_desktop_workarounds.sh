#!/bin/bash
# Flutter Desktop 运行时问题排查脚本
# 用于测试不同的 GLib-GObject 冲突解决方案

set -e

FLUTTER_DIR="mobile/cordyscrm_flutter"
BUILD_DIR="$FLUTTER_DIR/build/linux/x64/release/bundle"
APP_NAME="cordyscrm_flutter"

echo "=========================================="
echo "Flutter Desktop 运行时问题排查"
echo "=========================================="
echo ""

# 检查编译产物是否存在
if [ ! -f "$BUILD_DIR/$APP_NAME" ]; then
    echo "❌ 未找到编译产物，请先运行: flutter build linux --release"
    exit 1
fi

echo "✅ 找到编译产物: $BUILD_DIR/$APP_NAME"
echo ""

# 方案 1: 检查当前环境变量
echo "方案 1: 检查环境变量"
echo "----------------------------------------"
echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
echo "VCPKG_ROOT: $VCPKG_ROOT"
echo ""

# 方案 2: 检查依赖库
echo "方案 2: 检查应用依赖库"
echo "----------------------------------------"
ldd "$BUILD_DIR/$APP_NAME" | grep -E "(glib|gobject|dbus)" || echo "未找到相关库"
echo ""

# 方案 3: 检查 Flutter 插件库
echo "方案 3: 检查 Flutter 插件库"
echo "----------------------------------------"
if [ -f "$BUILD_DIR/lib/libflutter_linux_gtk.so" ]; then
    ldd "$BUILD_DIR/lib/libflutter_linux_gtk.so" | grep -E "(glib|gobject)" || echo "未找到相关库"
fi
echo ""

# 方案 4: 尝试清除 LD_LIBRARY_PATH 运行
echo "方案 4: 清除 LD_LIBRARY_PATH 后运行"
echo "----------------------------------------"
echo "尝试运行应用（5秒超时）..."
timeout 5 env -u LD_LIBRARY_PATH "$BUILD_DIR/$APP_NAME" 2>&1 | head -20 || echo "运行失败或超时"
echo ""

# 方案 5: 检查系统 GLib 版本
echo "方案 5: 检查系统 GLib 版本"
echo "----------------------------------------"
pkg-config --modversion glib-2.0 || echo "无法获取 GLib 版本"
pkg-config --modversion gobject-2.0 || echo "无法获取 GObject 版本"
echo ""

# 方案 6: 检查 vcpkg GLib 版本（如果存在）
echo "方案 6: 检查 vcpkg GLib 版本"
echo "----------------------------------------"
if [ -d "$HOME/vcpkg/installed/x64-linux/lib" ]; then
    ls -la "$HOME/vcpkg/installed/x64-linux/lib" | grep -E "libglib|libgobject" || echo "未找到 vcpkg GLib 库"
else
    echo "未找到 vcpkg 安装目录"
fi
echo ""

echo "=========================================="
echo "排查完成"
echo "=========================================="
echo ""
echo "建议："
echo "1. 在干净的 Docker 容器中测试"
echo "2. 临时移除 desktop_webview_window 依赖"
echo "3. 在其他 Linux 发行版上测试"
