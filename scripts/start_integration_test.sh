#!/bin/bash
# 集成测试环境启动脚本
# 用法: ./scripts/start_integration_test.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "启动 CordysCRM 集成测试环境"
echo "=========================================="
echo ""

# ------------------------------
# 1. 启动数据库服务
# ------------------------------
echo "步骤 1/3: 启动数据库服务..."
"$SCRIPT_DIR/start_databases.sh"

echo ""
echo "等待数据库完全就绪..."
sleep 5

# ------------------------------
# 2. 启动后端服务
# ------------------------------
echo ""
echo "步骤 2/3: 启动后端服务..."
echo "后端服务将在后台运行，日志输出到终端"
echo "使用 Ctrl+C 停止后端服务"
echo ""

# 检查后端是否已经在运行
if lsof -Pi :8081 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "⚠️  警告: 端口 8081 已被占用，后端服务可能已在运行"
    echo "如需重启，请先停止现有服务"
else
    echo "启动后端服务..."
    cd "$PROJECT_ROOT/backend"
    
    if [ -f "../mvnw" ]; then
        MVN="../mvnw"
    elif command -v mvn &> /dev/null; then
        MVN="mvn"
    else
        echo "❌ 错误: 未找到 Maven"
        exit 1
    fi
    
    # 在后台启动后端
    $MVN spring-boot:run -pl app -DskipTests > /tmp/cordys-backend.log 2>&1 &
    BACKEND_PID=$!
    echo "后端服务 PID: $BACKEND_PID"
    echo "日志文件: /tmp/cordys-backend.log"
    
    echo "等待后端服务启动..."
    for i in {1..60}; do
        if lsof -Pi :8081 -sTCP:LISTEN -t >/dev/null 2>&1; then
            echo "✓ 后端服务已启动 (端口 8081)"
            break
        fi
        if [ $i -eq 60 ]; then
            echo "❌ 后端服务启动超时"
            echo "查看日志: tail -f /tmp/cordys-backend.log"
            exit 1
        fi
        sleep 1
    done
fi

# ------------------------------
# 3. 启动 Flutter Android
# ------------------------------
echo ""
echo "步骤 3/3: 启动 Flutter Android 应用..."
echo ""

cd "$PROJECT_ROOT/mobile/cordyscrm_flutter"

# 检查 Android 设备
echo "检查 Android 设备..."
DEVICES=$(flutter devices | grep "android-arm" | head -1)

if [ -z "$DEVICES" ]; then
    echo "❌ 错误: 未找到 Android 设备"
    echo "请连接 Android 设备或启动模拟器"
    echo ""
    echo "可用设备:"
    flutter devices
    exit 1
fi

# 提取设备 ID
DEVICE_ID=$(echo "$DEVICES" | awk '{print $4}')
echo "找到 Android 设备: $DEVICE_ID"
echo ""

echo "启动 Flutter 应用..."
echo "提示: 应用将在设备上安装并运行"
echo "      使用 'r' 热重载, 'R' 热重启, 'q' 退出"
echo ""

# 启动 Flutter (前台运行，可以交互)
flutter run -d "$DEVICE_ID"

# 清理
echo ""
echo "=========================================="
echo "清理环境..."
echo "=========================================="

if [ ! -z "$BACKEND_PID" ]; then
    echo "停止后端服务 (PID: $BACKEND_PID)..."
    kill $BACKEND_PID 2>/dev/null || true
fi

echo "集成测试环境已关闭"
