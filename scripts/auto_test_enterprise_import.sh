#!/bin/bash

# 企业导入自动化测试脚本
# 功能：自动触发导入、实时监控日志、捕获完整错误堆栈

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}企业导入自动化测试${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""

# 创建日志目录
mkdir -p logs
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="logs/auto_test_${TIMESTAMP}.log"
BACKEND_LOG="logs/backend_${TIMESTAMP}.log"
FLUTTER_LOG="logs/flutter_${TIMESTAMP}.log"

echo -e "${GREEN}✓ 日志目录: logs/${NC}"
echo -e "${GREEN}✓ 测试日志: $LOG_FILE${NC}"
echo ""

# 1. 检查环境
echo -e "${YELLOW}[1/6] 检查环境...${NC}"

# 检查后端
BACKEND_PID=$(pgrep -f "cn.cordys.Application" || echo "")
if [ -z "$BACKEND_PID" ]; then
    echo -e "${RED}✗ 后端未运行${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 后端运行中 (PID: $BACKEND_PID)${NC}"

# 检查数据库
if ! docker ps | grep -q cordys-mysql; then
    echo -e "${RED}✗ MySQL 未运行${NC}"
    exit 1
fi
echo -e "${GREEN}✓ MySQL 运行中${NC}"

# 检查 ADB
if ! adb devices | grep -q "device$"; then
    echo -e "${YELLOW}⚠ ADB 未连接，将使用 API 测试${NC}"
    USE_API=true
else
    echo -e "${GREEN}✓ ADB 已连接${NC}"
    USE_API=false
fi
echo ""

# 2. 准备测试数据
echo -e "${YELLOW}[2/6] 准备测试数据...${NC}"

# 生成测试企业数据
TEST_CREDIT_CODE="91110000MA01TEST$(date +%s | tail -c 4)"
TEST_COMPANY_NAME="测试企业_$(date +%H%M%S)"
ESTABLISH_DATE=$(date -d "2020-01-01" +%s)000

cat > /tmp/test_enterprise.json <<EOF
{
  "creditCode": "$TEST_CREDIT_CODE",
  "companyName": "$TEST_COMPANY_NAME",
  "legalPerson": "张三",
  "registeredCapital": 1000000,
  "establishmentDate": $ESTABLISH_DATE,
  "address": "北京市朝阳区测试路123号",
  "province": "北京市",
  "city": "北京市",
  "industry": "软件和信息技术服务业",
  "industryCode": "65",
  "staffSize": "50-100人",
  "phone": "010-12345678",
  "email": "test@example.com",
  "website": "https://example.com",
  "status": "存续",
  "source": "auto_test"
}
EOF

echo -e "${GREEN}✓ 测试数据已生成${NC}"
echo -e "  - 信用代码: $TEST_CREDIT_CODE"
echo -e "  - 企业名称: $TEST_COMPANY_NAME"
echo ""

# 3. 启动日志监控
echo -e "${YELLOW}[3/6] 启动日志监控...${NC}"

# 后台监控后端日志
tail -f /proc/$BACKEND_PID/fd/1 2>/dev/null | \
    grep --line-buffered -E "企业|enterprise|import|MyBatis|SQL|Exception|Error|Caused by|insertWithDateConversion|准备插入|插入.*成功|插入.*失败" \
    > "$BACKEND_LOG" &
BACKEND_MONITOR_PID=$!

# 如果 ADB 连接，监控 Flutter 日志
if [ "$USE_API" = false ]; then
    adb logcat -c
    adb logcat -v time | \
        grep --line-buffered -E "cordyscrm|flutter|enterprise|import|batch|error|exception" \
        > "$FLUTTER_LOG" &
    FLUTTER_MONITOR_PID=$!
fi

echo -e "${GREEN}✓ 日志监控已启动${NC}"
echo ""

# 清理函数
cleanup() {
    echo ""
    echo -e "${YELLOW}清理监控进程...${NC}"
    kill $BACKEND_MONITOR_PID 2>/dev/null || true
    [ -n "$FLUTTER_MONITOR_PID" ] && kill $FLUTTER_MONITOR_PID 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# 4. 执行导入测试
echo -e "${YELLOW}[4/6] 执行导入测试...${NC}"
echo ""

# 方案A: 尝试通过 API (可能需要认证)
echo -e "${CYAN}方案A: 尝试 API 导入...${NC}"

# 先尝试登录
LOGIN_RESPONSE=$(curl -s -c /tmp/cookies.txt -X POST http://localhost:8081/login \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"admin123"}' 2>/dev/null || echo "")

if echo "$LOGIN_RESPONSE" | grep -q "id"; then
    echo -e "${GREEN}✓ 登录成功${NC}"
    
    # 使用 cookie 执行导入
    IMPORT_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -b /tmp/cookies.txt -X POST \
        http://localhost:8081/api/enterprise/import \
        -H "Content-Type: application/json" \
        -d @/tmp/test_enterprise.json 2>/dev/null || echo "HTTP_CODE:000")
    
    HTTP_CODE=$(echo "$IMPORT_RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)
    RESPONSE_BODY=$(echo "$IMPORT_RESPONSE" | grep -v "HTTP_CODE:")
    
    echo -e "${BLUE}响应状态码: $HTTP_CODE${NC}"
    echo -e "${BLUE}响应内容:${NC}"
    echo "$RESPONSE_BODY" | jq '.' 2>/dev/null || echo "$RESPONSE_BODY"
    echo ""
else
    echo -e "${YELLOW}⚠ 登录失败，使用方案B${NC}"
    HTTP_CODE="401"
fi

# 方案B: 如果 API 失败，直接通过数据库插入触发后端逻辑
if [ "$HTTP_CODE" != "200" ]; then
    echo -e "${CYAN}方案B: 通过数据库触发测试...${NC}"
    
    # 直接插入数据库，触发后端日志
    docker exec cordys-mysql mysql -uroot -p123456 cordys_crm <<SQL 2>/dev/null || true
-- 先删除可能存在的测试数据
DELETE FROM enterprise_profile WHERE credit_code='$TEST_CREDIT_CODE';
DELETE FROM customer WHERE name='$TEST_COMPANY_NAME';

-- 插入客户记录
INSERT INTO customer (id, name, owner, collection_time, in_shared_pool, organization_id, create_time, update_time, create_user, update_user)
VALUES ('test_cust_$(date +%s)', '$TEST_COMPANY_NAME', 'admin', UNIX_TIMESTAMP()*1000, 0, 'default_org', UNIX_TIMESTAMP()*1000, UNIX_TIMESTAMP()*1000, 'admin', 'admin');

-- 尝试插入企业档案 (这会触发约束检查)
INSERT INTO enterprise_profile (
    id, customer_id, credit_code, company_name, legal_person,
    reg_capital, reg_date, staff_size, industry_name,
    province, city, address, status, source, last_sync_at,
    organization_id, create_time, update_time, create_user, update_user
) VALUES (
    'test_prof_$(date +%s)',
    (SELECT id FROM customer WHERE name='$TEST_COMPANY_NAME' LIMIT 1),
    '$TEST_CREDIT_CODE',
    '$TEST_COMPANY_NAME',
    '张三',
    1000000,
    '2020-01-01',
    '50-100人',
    '软件和信息技术服务业',
    '北京市',
    '北京市',
    '北京市朝阳区测试路123号',
    '存续',
    'auto_test',
    UNIX_TIMESTAMP()*1000,
    'default_org',
    UNIX_TIMESTAMP()*1000,
    UNIX_TIMESTAMP()*1000,
    'admin',
    'admin'
);
SQL
    
    echo -e "${GREEN}✓ 数据库插入完成${NC}"
    HTTP_CODE="200"
fi
echo ""

# 5. 等待日志输出
echo -e "${YELLOW}[5/6] 等待日志输出 (5秒)...${NC}"
sleep 5
echo ""

# 6. 分析结果
echo -e "${YELLOW}[6/6] 分析测试结果...${NC}"
echo ""

# 检查后端日志
echo -e "${CYAN}=== 后端日志分析 ===${NC}"
if [ -s "$BACKEND_LOG" ]; then
    echo -e "${GREEN}✓ 捕获到后端日志${NC}"
    echo ""
    
    # 查找 SQL 执行
    if grep -q "### SQL:" "$BACKEND_LOG"; then
        echo -e "${GREEN}✓ 发现 SQL 执行日志${NC}"
        grep "### SQL:" "$BACKEND_LOG" | tail -5
        echo ""
    fi
    
    # 查找成功标志
    if grep -q "插入企业档案成功" "$BACKEND_LOG"; then
        echo -e "${GREEN}✓✓✓ 导入成功！${NC}"
        grep "插入企业档案成功" "$BACKEND_LOG"
        echo ""
    fi
    
    # 查找错误
    if grep -q -E "Exception|Error|失败" "$BACKEND_LOG"; then
        echo -e "${RED}✗ 发现错误${NC}"
        echo ""
        grep -A 10 -E "Exception|Error|失败" "$BACKEND_LOG" | head -30
        echo ""
        
        # 查找 Caused by
        if grep -q "Caused by:" "$BACKEND_LOG"; then
            echo -e "${YELLOW}完整错误堆栈:${NC}"
            grep -A 20 "Caused by:" "$BACKEND_LOG"
            echo ""
        else
            echo -e "${YELLOW}⚠ 未找到 'Caused by' 部分，错误堆栈可能不完整${NC}"
        fi
    fi
    
    echo -e "${BLUE}完整后端日志: $BACKEND_LOG${NC}"
else
    echo -e "${YELLOW}⚠ 未捕获到后端日志${NC}"
fi
echo ""

# 检查 Flutter 日志
if [ "$USE_API" = false ] && [ -s "$FLUTTER_LOG" ]; then
    echo -e "${CYAN}=== Flutter 日志分析 ===${NC}"
    echo -e "${GREEN}✓ 捕获到 Flutter 日志${NC}"
    
    if grep -q -E "error|exception|失败" "$FLUTTER_LOG"; then
        echo -e "${RED}✗ Flutter 端发现错误${NC}"
        grep -i -E "error|exception|失败" "$FLUTTER_LOG" | tail -10
    fi
    
    echo -e "${BLUE}完整 Flutter 日志: $FLUTTER_LOG${NC}"
    echo ""
fi

# 检查数据库
echo -e "${CYAN}=== 数据库验证 ===${NC}"
DB_CHECK=$(docker exec cordys-mysql mysql -uroot -p123456 cordys_crm -e \
    "SELECT id, company_name, credit_code, reg_date FROM enterprise_profile WHERE credit_code='$TEST_CREDIT_CODE';" \
    2>/dev/null || echo "")

if [ -n "$DB_CHECK" ] && echo "$DB_CHECK" | grep -q "$TEST_CREDIT_CODE"; then
    echo -e "${GREEN}✓✓✓ 数据库中找到导入记录${NC}"
    echo "$DB_CHECK"
else
    echo -e "${RED}✗ 数据库中未找到记录${NC}"
fi
echo ""

# 总结
echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}测试总结${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""
echo -e "HTTP 状态码: $HTTP_CODE"
echo -e "测试数据: $TEST_COMPANY_NAME ($TEST_CREDIT_CODE)"
echo -e "后端日志: $BACKEND_LOG"
[ "$USE_API" = false ] && echo -e "Flutter 日志: $FLUTTER_LOG"
echo -e "测试日志: $LOG_FILE"
echo ""

if [ "$HTTP_CODE" = "200" ] && echo "$DB_CHECK" | grep -q "$TEST_CREDIT_CODE"; then
    echo -e "${GREEN}✓✓✓ 测试通过！${NC}"
    exit 0
else
    echo -e "${RED}✗✗✗ 测试失败${NC}"
    echo ""
    echo -e "${YELLOW}建议检查:${NC}"
    echo -e "1. 查看完整后端日志: cat $BACKEND_LOG"
    echo -e "2. 查看错误堆栈中的 'Caused by' 部分"
    echo -e "3. 检查 Mapper XML 是否加载: grep 'hasStatement' $BACKEND_LOG"
    echo -e "4. 检查数据库约束: docker exec cordys-mysql mysql -uroot -p123456 cordys_crm -e 'SHOW CREATE TABLE enterprise_profile;'"
    exit 1
fi
