#!/bin/bash
# 数据库服务启动脚本（Docker 容器方式）
# 用法: ./scripts/start_databases.sh

set -e

echo "=========================================="
echo "启动 CordysCRM 数据库服务"
echo "=========================================="
echo ""

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    echo "❌ 错误: 未找到 Docker，请先安装 Docker"
    exit 1
fi

echo "Docker 版本:"
docker --version
echo ""

# MySQL 配置
MYSQL_CONTAINER_NAME="cordys-mysql"
MYSQL_PORT=3306
MYSQL_ROOT_PASSWORD="root"
MYSQL_DATABASE="cordys_crm"

# Redis 配置
REDIS_CONTAINER_NAME="cordys-redis"
REDIS_PORT=6379

# ------------------------------
# 启动 MySQL
# ------------------------------
echo "检查 MySQL 容器状态..."
if docker ps -a --format '{{.Names}}' | grep -q "^${MYSQL_CONTAINER_NAME}$"; then
    echo "MySQL 容器已存在"
    
    if docker ps --format '{{.Names}}' | grep -q "^${MYSQL_CONTAINER_NAME}$"; then
        echo "✓ MySQL 容器正在运行"
    else
        echo "启动 MySQL 容器..."
        docker start ${MYSQL_CONTAINER_NAME}
        echo "✓ MySQL 容器已启动"
    fi
else
    echo "创建并启动 MySQL 容器..."
    docker run -d \
        --name ${MYSQL_CONTAINER_NAME} \
        --restart unless-stopped \
        -p ${MYSQL_PORT}:3306 \
        -e MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD} \
        -e MYSQL_DATABASE=${MYSQL_DATABASE} \
        -e MYSQL_ROOT_HOST=% \
        mysql:8.0 \
        --character-set-server=utf8mb4 \
        --collation-server=utf8mb4_unicode_ci \
        --default-authentication-plugin=mysql_native_password
    
    echo "✓ MySQL 容器已创建并启动"
    echo "等待 MySQL 初始化..."
    sleep 10
fi

# ------------------------------
# 启动 Redis
# ------------------------------
echo ""
echo "检查 Redis 容器状态..."
if docker ps -a --format '{{.Names}}' | grep -q "^${REDIS_CONTAINER_NAME}$"; then
    echo "Redis 容器已存在"
    
    if docker ps --format '{{.Names}}' | grep -q "^${REDIS_CONTAINER_NAME}$"; then
        echo "✓ Redis 容器正在运行"
    else
        echo "启动 Redis 容器..."
        docker start ${REDIS_CONTAINER_NAME}
        echo "✓ Redis 容器已启动"
    fi
else
    echo "创建并启动 Redis 容器..."
    docker run -d \
        --name ${REDIS_CONTAINER_NAME} \
        --restart unless-stopped \
        -p ${REDIS_PORT}:6379 \
        redis:7-alpine
    
    echo "✓ Redis 容器已创建并启动"
fi

# ------------------------------
# 验证服务状态
# ------------------------------
echo ""
echo "=========================================="
echo "验证服务状态"
echo "=========================================="

echo ""
echo "MySQL 容器状态:"
docker ps --filter "name=${MYSQL_CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "Redis 容器状态:"
docker ps --filter "name=${REDIS_CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "=========================================="
echo "数据库服务启动完成！"
echo "=========================================="
echo ""
echo "MySQL 连接信息:"
echo "  地址: 127.0.0.1:${MYSQL_PORT}"
echo "  用户名: root"
echo "  密码: ${MYSQL_ROOT_PASSWORD}"
echo "  数据库: ${MYSQL_DATABASE}"
echo ""
echo "Redis 连接信息:"
echo "  地址: 127.0.0.1:${REDIS_PORT}"
echo ""
