#!/bin/bash

# 测试企业批量导入调试脚本
# 用于验证 insertWithDateConversion 方法是否被正确调用

set -e

echo "========================================="
echo "企业批量导入调试测试"
echo "========================================="

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 环境变量（可覆盖）
BASE_URL="${BASE_URL:-http://localhost:8080}"
USERNAME="${USERNAME:-admin}"
PASSWORD="${PASSWORD:-admin123}"
LOG_PATH="${LOG_PATH:-logs}"

# 检查 jq 是否可用
HAS_JQ=false
if command -v jq &> /dev/null; then
    HAS_JQ=true
fi

# 1. 检查后端是否运行
echo -e "\n${YELLOW}1. 检查后端服务状态...${NC}"
if ! curl -s "${BASE_URL}/actuator/health" > /dev/null 2>&1; then
    echo -e "${RED}后端服务未运行！${NC}"
    echo "请先启动后端服务："
    echo "  cd backend && mvn spring-boot:run"
    exit 1
fi
echo -e "${GREEN}✓ 后端服务正在运行${NC}"

# 2. 编译最新代码
echo -e "\n${YELLOW}2. 编译最新代码...${NC}"
cd backend/crm
mvn compile -DskipTests -q
cd ../..
echo -e "${GREEN}✓ 编译完成${NC}"

# 3. 准备测试数据
echo -e "\n${YELLOW}3. 准备测试数据...${NC}"
TEST_DATA='{
  "companyName": "测试企业调试",
  "creditCode": "91110000MA01234567",
  "legalPerson": "张三",
  "regCapital": "1000000",
  "regDate": 1609459200000,
  "address": "北京市朝阳区测试路123号",
  "status": "存续",
  "phone": "010-12345678",
  "email": "test@example.com"
}'

# 4. 获取登录 token
echo -e "\n${YELLOW}4. 获取登录 token...${NC}"
LOGIN_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/login" \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"${USERNAME}\",
    \"password\": \"${PASSWORD}\"
  }")

# 提取 token（兼容有无 jq 的情况）
if [ "$HAS_JQ" = true ]; then
    TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.token // empty')
else
    TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
fi

if [ -z "$TOKEN" ]; then
    echo -e "${RED}登录失败！${NC}"
    echo "响应: $LOGIN_RESPONSE"
    exit 1
fi
echo -e "${GREEN}✓ 登录成功${NC}"

# 5. 调用企业导入接口
echo -e "\n${YELLOW}5. 调用企业导入接口...${NC}"
echo "测试数据: $TEST_DATA"

IMPORT_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/enterprise/import" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "$TEST_DATA")

echo -e "\n导入响应:"
if [ "$HAS_JQ" = true ]; then
    echo "$IMPORT_RESPONSE" | jq '.'
else
    echo "$IMPORT_RESPONSE"
fi

# 检查响应是否包含错误
if echo "$IMPORT_RESPONSE" | grep -qi "error\|exception"; then
    echo -e "${RED}✗ 导入失败！${NC}"
else
    echo -e "${GREEN}✓ 导入成功${NC}"
fi

# 6. 检查日志
echo -e "\n${YELLOW}6. 检查后端日志...${NC}"
echo "查找关键日志信息："
echo ""

# 查找最近的日志文件
LOG_FILE=$(find "$LOG_PATH" -name "cordys-crm*.log" -type f -mmin -5 2>/dev/null | head -1)

if [ -z "$LOG_FILE" ]; then
    echo -e "${YELLOW}未找到最近的日志文件，尝试查找所有日志...${NC}"
    LOG_FILE=$(find . -name "*.log" -type f -mmin -5 2>/dev/null | head -1)
fi

if [ -n "$LOG_FILE" ]; then
    echo "日志文件: $LOG_FILE"
    echo ""
    echo "=== Mapper 类信息 ==="
    grep "Mapper class:" "$LOG_FILE" | tail -5
    echo ""
    echo "=== hasStatement 检查 ==="
    grep "hasStatement" "$LOG_FILE" | tail -5
    echo ""
    echo "=== 插入企业档案 ==="
    grep "插入企业档案" "$LOG_FILE" | tail -5
    echo ""
    echo "=== 错误信息 ==="
    ERROR_COUNT=$(grep -i "error\|exception" "$LOG_FILE" | wc -l)
    if [ "$ERROR_COUNT" -gt 0 ]; then
        echo -e "${RED}发现 $ERROR_COUNT 个错误：${NC}"
        grep -i "error\|exception" "$LOG_FILE" | tail -10
        
        # 检查是否有 DataAccessLayer$Executor.insert 错误
        if grep -q "DataAccessLayer\$Executor.insert" "$LOG_FILE"; then
            echo -e "\n${RED}✗ 发现 DataAccessLayer\$Executor.insert 调用！${NC}"
            echo "这说明代码仍在使用 BaseMapper 而不是 ExtEnterpriseProfileMapper"
            exit 1
        fi
    else
        echo -e "${GREEN}未发现错误${NC}"
    fi
else
    echo -e "${YELLOW}未找到日志文件${NC}"
    echo "请手动检查后端控制台输出"
fi

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}测试完成！${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "如果看到错误，请检查："
echo "1. Mapper class 是否为代理类"
echo "2. hasStatement 是否返回 true"
echo "3. 是否有 DataAccessLayer\$Executor.insert 的堆栈"
echo ""
echo "环境变量配置："
echo "  BASE_URL=${BASE_URL}"
echo "  USERNAME=${USERNAME}"
echo "  LOG_PATH=${LOG_PATH}"
