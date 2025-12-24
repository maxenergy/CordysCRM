#!/bin/bash
# Flutter 代码分析脚本
# 用法: ./scripts/flutter_analyze.sh

set -e

echo "开始 Flutter 代码分析..."
cd mobile/cordyscrm_flutter
flutter analyze

echo "✓ Flutter 代码分析完成"
