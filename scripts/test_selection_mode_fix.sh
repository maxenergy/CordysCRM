#!/bin/bash

# 测试企业搜索选择模式修复
# 此脚本重新编译 Flutter Android APK 并安装到设备

set -e

echo "========================================="
echo "测试企业搜索选择模式修复"
echo "========================================="

cd mobile/cordyscrm_flutter

echo ""
echo "1. 清理构建缓存..."
flutter clean

echo ""
echo "2. 获取依赖..."
flutter pub get

echo ""
echo "3. 编译 Android APK (release)..."
flutter build apk --release

echo ""
echo "4. 检查 APK 文件..."
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK_PATH" ]; then
    echo "✓ APK 文件已生成: $APK_PATH"
    ls -lh "$APK_PATH"
else
    echo "✗ APK 文件未找到"
    exit 1
fi

echo ""
echo "5. 检查连接的设备..."
adb devices

echo ""
echo "6. 安装 APK 到设备..."
adb install -r "$APK_PATH"

echo ""
echo "========================================="
echo "安装完成！"
echo "========================================="
echo ""
echo "测试步骤："
echo "1. 打开应用并登录"
echo "2. 进入企业搜索页面"
echo "3. 搜索一个企业名称（例如：腾讯）"
echo "4. 观察日志输出，查看："
echo "   - 搜索结果的 source 字段"
echo "   - isLocal 字段的值"
echo "   - 是否显示"选择"按钮"
echo "5. 如果有远程企业，点击"选择"按钮进入选择模式"
echo "6. 检查是否显示底部的 SelectionBar"
echo ""
echo "查看日志："
echo "adb logcat | grep -E '企业搜索|企查查搜索|选择模式'"
echo ""
