#!/bin/bash
# Flutter 依赖修复脚本
# 用法: ./scripts/fix_flutter_dependencies.sh

set -e  # 遇错即停

echo "=========================================="
echo "Flutter 依赖修复脚本"
echo "=========================================="

cd mobile/cordyscrm_flutter

# 1. 备份当前配置
echo ""
echo "[1/7] 备份当前依赖配置..."
cp pubspec.yaml pubspec.yaml.backup
cp pubspec.lock pubspec.lock.backup
echo "✓ 备份完成: pubspec.yaml.backup, pubspec.lock.backup"

# 2. 清理构建缓存
echo ""
echo "[2/7] 清理构建缓存..."
flutter clean
echo "✓ 构建缓存已清理"

# 3. 修改 pubspec.yaml（锁定 file_picker 版本）
echo ""
echo "[3/7] 修改 pubspec.yaml，锁定 file_picker 到 8.1.7..."
sed -i 's/file_picker: \^6\.1\.1/file_picker: 8.1.7/' pubspec.yaml
echo "✓ file_picker 版本已更新为 8.1.7（支持 web ^1.0.0）"

# 4. 获取依赖（不升级其他包）
echo ""
echo "[4/7] 获取依赖..."
flutter pub get
echo "✓ 依赖获取完成"

# 5. 运行静态分析
echo ""
echo "[5/7] 运行静态分析..."
flutter analyze || echo "⚠ 存在分析警告，请检查"

# 6. 尝试构建 Android APK
echo ""
echo "[6/7] 尝试构建 Android APK..."
flutter build apk --debug
echo "✓ Android 构建成功！"

# 7. 显示 file_picker 版本
echo ""
echo "[7/7] 验证 file_picker 版本..."
grep "file_picker:" pubspec.lock | head -1
echo ""
echo "=========================================="
echo "✓ 依赖修复完成！"
echo "=========================================="
echo ""
echo "下一步："
echo "1. 运行 flutter run -d <device_id> 在真机上测试"
echo "2. 测试文件选择功能"
echo "3. 如果一切正常，删除备份文件并提交代码"
