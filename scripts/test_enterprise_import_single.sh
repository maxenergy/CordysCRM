#!/bin/bash

# 单条企业导入测试脚本
# 用途：测试单条企业导入，验证日期转换和数据库约束

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
BASE_URL="${BASE_URL:-http://localhost:8080}"
USERNAME="${USERNAME:-admin}"
PASSWORD="${PASSWORD:-admin123}"

echo "========================================="
echo "单条企业导入测试"
echo "========================================="
echo ""

# 1. 检查后端服务
echo -e "${YELLOW}[1/4] 检查后端服务...${NC}"
if curl -s -f "${BASE_URL}/actuator/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ 后端服务正常${NC}"
else
    echo -e "${RED}✗ 后端服务不可用${NC}"
    echo "请先运行: ./scripts/debug_enterprise_import.sh"
    exit 1
fi

# 2. 登录获取 token
echo -e "${YELLOW}[2/4] 登录获取 token...${NC}"
LOGIN_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${USERNAME}\",\"password\":\"${PASSWORD}\"}")

TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    echo -e "${RED}✗ 登录失败${NC}"
    echo "响应: $LOGIN_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓ 登录成功${NC}"
echo "Token: ${TOKEN:0:20}..."

# 3. 测试单条导入
echo -e "${YELLOW}[3/4] 测试单条企业导入...${NC}"
echo ""

# 生成唯一的信用代码（避免重复）
TIMESTAMP=$(date +%s)
CREDIT_CODE="91110000TEST${TIMESTAMP}"

echo -e "${BLUE}测试数据：${NC}"
echo "  企业名称: 测试企业-${TIMESTAMP}"
echo "  信用代码: ${CREDIT_CODE}"
echo "  成立日期: 2021-01-01 (1609459200000)"
echo ""

IMPORT_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/enterprise/import" \
  -H "Content-Type: application/json" \
  -H "X-AUTH-TOKEN: ${TOKEN}" \
  -d "{
    \"companyName\":\"测试企业-${TIMESTAMP}\",
    \"creditCode\":\"${CREDIT_CODE}\",
    \"legalPerson\":\"张三\",
    \"registeredCapital\":1000000.50,
    \"establishmentDate\":1609459200000,
    \"address\":\"北京市朝阳区测试路123号\",
    \"province\":\"北京市\",
    \"city\":\"朝阳区\",
    \"industry\":\"软件和信息技术服务业\",
    \"industryCode\":\"I65\",
    \"staffSize\":\"50-100人\",
    \"phone\":\"010-12345678\",
    \"email\":\"test@example.com\",
    \"website\":\"https://example.com\",
    \"status\":\"存续\",
    \"shareholders\":\"{\\\"name\\\":\\\"股东A\\\",\\\"ratio\\\":60}\",
    \"executives\":\"{\\\"name\\\":\\\"高管B\\\",\\\"position\\\":\\\"CEO\\\"}\",
    \"risks\":\"{\\\"type\\\":\\\"经营异常\\\",\\\"count\\\":0}\"
  }")

echo -e "${BLUE}导入响应：${NC}"
echo "$IMPORT_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$IMPORT_RESPONSE"
echo ""

# 4. 检查结果
echo -e "${YELLOW}[4/4] 检查导入结果...${NC}"

SUCCESS=$(echo "$IMPORT_RESPONSE" | grep -o '"success":[^,}]*' | cut -d':' -f2)

if [ "$SUCCESS" = "true" ]; then
    echo -e "${GREEN}✓ 导入成功！${NC}"
    
    CUSTOMER_ID=$(echo "$IMPORT_RESPONSE" | grep -o '"customerId":"[^"]*"' | cut -d'"' -f4)
    echo "客户ID: $CUSTOMER_ID"
    
    echo ""
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}测试通过！${NC}"
    echo -e "${GREEN}=========================================${NC}"
else
    echo -e "${RED}✗ 导入失败${NC}"
    
    ERROR_MSG=$(echo "$IMPORT_RESPONSE" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
    echo "错误信息: $ERROR_MSG"
    
    echo ""
    echo -e "${RED}=========================================${NC}"
    echo -e "${RED}测试失败！${NC}"
    echo -e "${RED}=========================================${NC}"
    echo ""
    echo -e "${YELLOW}请检查后端日志：${NC}"
    echo "  tail -f logs/enterprise-import-debug.log"
    exit 1
fi

