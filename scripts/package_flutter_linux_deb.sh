#!/bin/bash
# Flutter Linux DEB 打包脚本
# 用法: ./scripts/package_flutter_linux_deb.sh

set -e  # 遇错即停

# 配置区域
APP_NAME="cordyscrm-flutter"
APP_VERSION="1.0.0"
APP_DESCRIPTION="CordysCRM Flutter 移动端应用 - Linux 桌面版"
MAINTAINER="CordysCRM Team <team@cordyscrm.com>"
ARCHITECTURE="amd64"

FLUTTER_DIR="mobile/cordyscrm_flutter"
BUNDLE_DIR="$FLUTTER_DIR/build/linux/x64/release/bundle"
PACKAGE_DIR="build/deb-package"
DEB_ROOT="$PACKAGE_DIR/$APP_NAME"

echo "=========================================="
echo "Flutter Linux DEB 打包脚本"
echo "=========================================="
echo "应用名称: $APP_NAME"
echo "版本: $APP_VERSION"
echo "架构: $ARCHITECTURE"
echo ""

# 检查 release bundle 是否存在
if [ ! -d "$BUNDLE_DIR" ]; then
    echo "❌ 错误: Release bundle 不存在"
    echo "请先运行: ./scripts/build_flutter_linux_release.sh"
    exit 1
fi

# 清理旧的打包目录
echo "🧹 清理旧的打包目录..."
rm -rf "$PACKAGE_DIR"

# 创建 DEB 包目录结构
echo "📁 创建 DEB 包目录结构..."
mkdir -p "$DEB_ROOT/DEBIAN"
mkdir -p "$DEB_ROOT/usr/bin"
mkdir -p "$DEB_ROOT/usr/lib/$APP_NAME"
mkdir -p "$DEB_ROOT/usr/share/applications"
mkdir -p "$DEB_ROOT/usr/share/pixmaps"
mkdir -p "$DEB_ROOT/usr/share/doc/$APP_NAME"

# 创建 DEBIAN/control 文件
echo "📝 创建 control 文件..."
cat > "$DEB_ROOT/DEBIAN/control" << EOF
Package: $APP_NAME
Version: $APP_VERSION
Section: utils
Priority: optional
Architecture: $ARCHITECTURE
Maintainer: $MAINTAINER
Description: $APP_DESCRIPTION
 CordysCRM Flutter 是一款现代化的客户关系管理移动应用，
 支持客户管理、线索跟进、商机管理等功能。
 .
 本包为 Linux 桌面版本。
Depends: libgtk-3-0, libglib2.0-0, libgdk-pixbuf2.0-0, libcairo2, libpango-1.0-0
EOF

# 复制应用文件
echo "📦 复制应用文件..."
cp -r "$BUNDLE_DIR"/* "$DEB_ROOT/usr/lib/$APP_NAME/"

# 创建启动脚本
echo "🚀 创建启动脚本..."
cat > "$DEB_ROOT/usr/bin/$APP_NAME" << 'EOF'
#!/bin/bash
# CordysCRM Flutter 启动脚本

APP_DIR="/usr/lib/cordyscrm-flutter"
cd "$APP_DIR"
exec "$APP_DIR/cordyscrm_flutter" "$@"
EOF

chmod +x "$DEB_ROOT/usr/bin/$APP_NAME"

# 创建 .desktop 文件
echo "🖥️  创建桌面启动器..."
cat > "$DEB_ROOT/usr/share/applications/$APP_NAME.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=CordysCRM Flutter
Comment=$APP_DESCRIPTION
Exec=$APP_NAME
Icon=$APP_NAME
Terminal=false
Categories=Office;ContactManagement;
Keywords=CRM;Customer;Management;
EOF

# 创建占位图标（实际项目中应该使用真实图标）
echo "🎨 创建应用图标..."
# 这里创建一个简单的 SVG 图标作为占位符
cat > "$DEB_ROOT/usr/share/pixmaps/$APP_NAME.svg" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg width="64" height="64" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
  <rect width="64" height="64" rx="8" fill="#2196F3"/>
  <text x="32" y="42" font-family="Arial" font-size="32" font-weight="bold" 
        text-anchor="middle" fill="white">C</text>
</svg>
EOF

# 创建版权和文档文件
echo "📄 创建文档文件..."
cat > "$DEB_ROOT/usr/share/doc/$APP_NAME/copyright" << EOF
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: CordysCRM Flutter
Source: https://github.com/cordyscrm/cordyscrm

Files: *
Copyright: 2024 CordysCRM Team
License: Proprietary
 This is proprietary software.
EOF

cat > "$DEB_ROOT/usr/share/doc/$APP_NAME/changelog" << EOF
$APP_NAME ($APP_VERSION) stable; urgency=medium

  * Initial release
  * Desktop platform support (Linux, Windows, macOS)
  * Responsive layout adaptation
  * Window management
  * File picker integration
  * Performance optimization
  * UI enhancements

 -- $MAINTAINER  $(date -R)
EOF

gzip -9 "$DEB_ROOT/usr/share/doc/$APP_NAME/changelog"

# 设置正确的权限
echo "🔒 设置文件权限..."
find "$DEB_ROOT" -type d -exec chmod 755 {} \;
find "$DEB_ROOT" -type f -exec chmod 644 {} \;
chmod +x "$DEB_ROOT/usr/bin/$APP_NAME"
chmod +x "$DEB_ROOT/usr/lib/$APP_NAME/cordyscrm_flutter"

# 构建 DEB 包
echo ""
echo "🏗️  构建 DEB 包..."
DEB_FILE="$PACKAGE_DIR/${APP_NAME}_${APP_VERSION}_${ARCHITECTURE}.deb"
dpkg-deb --build "$DEB_ROOT" "$DEB_FILE"

# 显示包信息
echo ""
echo "✅ DEB 包构建完成！"
echo ""
echo "📦 包文件: $DEB_FILE"
echo "📊 包大小: $(du -h "$DEB_FILE" | cut -f1)"
echo ""
echo "📋 包信息:"
dpkg-deb --info "$DEB_FILE"
echo ""
echo "📂 包内容:"
dpkg-deb --contents "$DEB_FILE" | head -20
echo ""
echo "🚀 安装命令:"
echo "   sudo dpkg -i $DEB_FILE"
echo ""
echo "🗑️  卸载命令:"
echo "   sudo dpkg -r $APP_NAME"
echo ""
echo "✅ 打包完成！"
