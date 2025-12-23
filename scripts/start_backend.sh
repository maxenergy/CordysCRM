#!/bin/bash
# 后端服务启动脚本
# 用法: ./scripts/start_backend.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKEND_DIR="$PROJECT_ROOT/backend"

echo "=========================================="
echo "启动 CRM 后端服务"
echo "=========================================="
echo "项目根目录: $PROJECT_ROOT"
echo "后端目录: $BACKEND_DIR"
echo ""

# 检查 Java 环境
if ! command -v java &> /dev/null; then
    echo "❌ 错误: 未找到 Java，请先安装 JDK"
    exit 1
fi

echo "Java 版本:"
java -version 2>&1 | head -1
echo ""

# 进入后端目录
cd "$BACKEND_DIR"

# 检查是否有 Maven wrapper
if [ -f "../mvnw" ]; then
    MVN="../mvnw"
elif command -v mvn &> /dev/null; then
    MVN="mvn"
else
    echo "❌ 错误: 未找到 Maven，请先安装 Maven 或使用 mvnw"
    exit 1
fi

echo "使用 Maven: $MVN"
echo ""

# 启动后端服务
echo "正在启动后端服务..."
echo "命令: $MVN spring-boot:run -pl app -DskipTests"
echo ""

$MVN spring-boot:run -pl app -DskipTests
