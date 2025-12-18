#!/bin/bash

# ============================================
# CRM 系统测试执行脚本
# ============================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 数据库配置（请根据实际情况修改）
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-3306}"
DB_NAME="${DB_NAME:-cordys_crm}"
DB_USER="${DB_USER:-root}"
DB_PASS="${DB_PASS:-}"

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}CRM 系统测试准备${NC}"
echo -e "${GREEN}============================================${NC}"

# 函数：执行 SQL 脚本
run_sql() {
    local sql_file=$1
    local description=$2
    
    echo -e "${YELLOW}>>> $description${NC}"
    
    if [ -z "$DB_PASS" ]; then
        mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" "$DB_NAME" < "$sql_file"
    else
        mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$sql_file"
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $description 完成${NC}"
    else
        echo -e "${RED}✗ $description 失败${NC}"
        exit 1
    fi
}

# 确认执行
echo ""
echo -e "${YELLOW}警告：此脚本将清理测试环境数据！${NC}"
echo "数据库: $DB_HOST:$DB_PORT/$DB_NAME"
echo ""
read -p "确认执行？(y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "已取消"
    exit 0
fi

# 步骤 1：备份数据库（可选）
echo ""
echo -e "${GREEN}步骤 1: 备份数据库（可选）${NC}"
read -p "是否备份数据库？(y/N) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    BACKUP_FILE="backup_$(date +%Y%m%d_%H%M%S).sql"
    echo "正在备份到 $BACKUP_FILE ..."
    if [ -z "$DB_PASS" ]; then
        mysqldump -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" "$DB_NAME" > "$SCRIPT_DIR/$BACKUP_FILE"
    else
        mysqldump -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$SCRIPT_DIR/$BACKUP_FILE"
    fi
    echo -e "${GREEN}✓ 备份完成: $BACKUP_FILE${NC}"
fi

# 步骤 2：清理模拟数据
echo ""
echo -e "${GREEN}步骤 2: 清理模拟数据${NC}"
run_sql "$SCRIPT_DIR/01_cleanup_mock_data.sql" "清理模拟数据"

# 步骤 3：创建测试用户
echo ""
echo -e "${GREEN}步骤 3: 创建测试用户${NC}"
run_sql "$SCRIPT_DIR/02_create_test_users.sql" "创建测试用户"

# 完成
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}测试数据准备完成！${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "测试用户列表："
echo "  - 13902213704 (销售经理)"
echo "  - 18911537991 (销售专员)"
echo "  - 15510322935 (销售专员)"
echo "  - 13762420030 (销售专员)"
echo "  - 18942021073 (销售专员)"
echo "  - 13716013451 (组织管理员)"
echo ""
echo "统一密码: Cordys@2024"
echo ""
echo "下一步："
echo "  1. 重启后端服务"
echo "  2. 按测试计划执行测试用例"
echo "  3. 记录测试结果"
