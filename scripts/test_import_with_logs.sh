#!/bin/bash

# 自动测试企业导入并捕获完整日志

set -e

echo "========================================="
echo "企业导入自动测试（含日志捕获）"
echo "========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 创建日志目录
mkdir -p logs
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="logs/import_test_${TIMESTAMP}.log"

echo -e "${GREEN}✓ 日志将保存到: $LOG_FILE${NC}"
echo ""

# 1. 检查后端状态
echo -e "${YELLOW}[1/4] 检查后端状态...${NC}"
if pgrep -f "cn.cordys.Application" > /dev/null; then
    echo -e "${GREEN}✓ 后端正在运行${NC}"
    BACKEND_PID=$(pgrep -f "cn.cordys.Application")
    echo "  PID: $BACKEND_PID"
else
    echo -e "${RED}✗ 后端未运行${NC}"
    exit 1
fi
echo ""

# 2. 检查 Mapper XML
echo -e "${YELLOW}[2/4] 检查 Mapper XML...${NC}"
MAPPER_XML="backend/crm/target/classes/cn/cordys/crm/integration/mapper/ExtEnterpriseProfileMapper.xml"
if [ -f "$MAPPER_XML" ]; then
    echo -e "${GREEN}✓ Mapper XML 存在${NC}"
    if grep -q "insertWithDateConversion" "$MAPPER_XML"; then
        echo -e "${GREEN}✓ insertWithDateConversion 方法已定义${NC}"
    else
        echo -e "${RED}✗ insertWithDateConversion 方法未找到${NC}"
        exit 1
    fi
    if grep -q "jdbcType=DATE" "$MAPPER_XML"; then
        echo -e "${GREEN}✓ jdbcType=DATE 已配置${NC}"
    else
        echo -e "${RED}✗ jdbcType=DATE 未配置${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Mapper XML 不存在${NC}"
    echo "需要重新编译: cd backend/crm && mvn clean compile -DskipTests"
    exit 1
fi
echo ""

# 3. 准备测试数据
echo -e "${YELLOW}[3/4] 准备测试数据...${NC}"
TEST_DATA='{
  "creditCode": "91110000MA01234567",
  "companyName": "测试企业有限公司",
  "legalPerson": "张三",
  "registeredCapital": 1000000,
  "establishmentDate": 1609459200000,
  "address": "北京市朝阳区测试路123号",
  "province": "北京市",
  "city": "北京市",
  "industry": "软件和信息技术服务业",
  "industryCode": "I65",
  "staffSize": "50-100人",
  "phone": "010-12345678",
  "email": "test@example.com",
  "website": "https://www.example.com",
  "status": "存续",
  "source": "test",
  "iqichaId": "test_'"$TIMESTAMP"'"
}'

echo "测试数据:"
echo "$TEST_DATA" | jq '.' 2>/dev/null || echo "$TEST_DATA"
echo ""

# 4. 执行导入并捕获日志
echo -e "${YELLOW}[4/4] 执行导入测试...${NC}"
echo ""

# 启动后端日志监控
echo -e "${BLUE}开始监控后端日志...${NC}"
(
    tail -f /proc/$BACKEND_PID/fd/1 2>/dev/null | \
    grep --line-buffered -E "企业|enterprise|import|MyBatis|SQL|Exception|Error|Caused by|insertWithDateConversion|hasStatement|准备插入|插入.*成功|插入.*失败" | \
    tee -a "$LOG_FILE"
) &
MONITOR_PID=$!

# 等待监控启动
sleep 2

# 发送导入请求
echo -e "${BLUE}发送导入请求...${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "Cookie: SESSION=test-session" \
    -d "$TEST_DATA" \
    http://localhost:8081/api/enterprise/import 2>&1 || echo "CURL_ERROR")

# 等待日志输出
sleep 3

# 停止监控
kill $MONITOR_PID 2>/dev/null || true

echo ""
echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}测试结果${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""

# 解析响应
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
RESPONSE_BODY=$(echo "$RESPONSE" | head -n -1)

echo "HTTP 状态码: $HTTP_CODE"
echo ""
echo "响应内容:"
echo "$RESPONSE_BODY" | jq '.' 2>/dev/null || echo "$RESPONSE_BODY"
echo ""

# 检查结果
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ 导入请求成功（HTTP 200）${NC}"
else
    echo -e "${RED}✗ 导入请求失败（HTTP $HTTP_CODE）${NC}"
fi
echo ""

# 分析日志
echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}日志分析${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""

if [ -f "$LOG_FILE" ]; then
    echo -e "${BLUE}=== SQL 执行日志 ===${NC}"
    grep "### SQL:" "$LOG_FILE" || echo "未找到 SQL 日志"
    echo ""
    
    echo -e "${BLUE}=== 参数日志 ===${NC}"
    grep "### Parameters:" "$LOG_FILE" || echo "未找到参数日志"
    echo ""
    
    echo -e "${BLUE}=== 插入状态 ===${NC}"
    grep -E "准备插入|插入.*成功|插入.*失败" "$LOG_FILE" || echo "未找到插入状态日志"
    echo ""
    
    echo -e "${BLUE}=== 异常信息 ===${NC}"
    grep -A 20 "Exception\|Error" "$LOG_FILE" || echo "未找到异常"
    echo ""
    
    echo -e "${BLUE}=== Caused by 链 ===${NC}"
    grep -A 5 "Caused by" "$LOG_FILE" || echo "未找到 Caused by"
    echo ""
else
    echo -e "${RED}✗ 日志文件不存在${NC}"
fi

echo ""
echo -e "${GREEN}完整日志已保存到: $LOG_FILE${NC}"
echo ""

# 检查数据库
echo -e "${YELLOW}检查数据库记录...${NC}"
if command -v mysql &> /dev/null; then
    mysql -u root -p123456 cordys_crm -e "
        SELECT id, company_name, credit_code, reg_date, 
               FROM_UNIXTIME(create_time/1000) as created_at
        FROM enterprise_profile 
        WHERE credit_code = '91110000MA01234567'
        ORDER BY create_time DESC 
        LIMIT 1;" 2>/dev/null || echo "数据库查询失败"
fi

echo ""
echo "========================================="
echo "测试完成"
echo "========================================="

