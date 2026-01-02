#!/bin/bash

# 直接通过数据库测试后端逻辑
# 绕过 HTTP 认证,直接触发 SQL 执行

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}后端直接测试${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""

# 生成测试数据
TEST_CREDIT_CODE="91110000MA01TEST$(date +%s | tail -c 4)"
TEST_COMPANY_NAME="测试企业_$(date +%H%M%S)"
TEST_CUSTOMER_ID="test_cust_$(date +%s)"
TEST_PROFILE_ID="test_prof_$(date +%s)"

echo -e "${YELLOW}测试数据:${NC}"
echo -e "  信用代码: $TEST_CREDIT_CODE"
echo -e "  企业名称: $TEST_COMPANY_NAME"
echo ""

# 检查后端
BACKEND_PID=$(pgrep -f "cn.cordys.Application" || echo "")
if [ -z "$BACKEND_PID" ]; then
    echo -e "${RED}✗ 后端未运行${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 后端运行中 (PID: $BACKEND_PID)${NC}"
echo ""

# 启动后端日志监控
echo -e "${YELLOW}启动日志监控...${NC}"
mkdir -p logs
LOG_FILE="logs/backend_direct_test_$(date +%Y%m%d_%H%M%S).log"

tail -f /proc/$BACKEND_PID/fd/1 2>/dev/null | \
    grep --line-buffered -E "企业|enterprise|import|MyBatis|SQL|Exception|Error|Caused by|insertWithDateConversion|准备插入|插入.*成功|插入.*失败" \
    > "$LOG_FILE" &
MONITOR_PID=$!

cleanup() {
    kill $MONITOR_PID 2>/dev/null || true
}
trap cleanup EXIT

echo -e "${GREEN}✓ 监控已启动${NC}"
echo ""

# 执行数据库插入
echo -e "${YELLOW}执行数据库插入...${NC}"

docker exec cordys-mysql mysql -uroot -p123456 cordys_crm <<SQL
-- 清理可能存在的测试数据
DELETE FROM enterprise_profile WHERE credit_code='$TEST_CREDIT_CODE';
DELETE FROM customer WHERE id='$TEST_CUSTOMER_ID';

-- 插入客户记录
INSERT INTO customer (
    id, name, owner, collection_time, in_shared_pool, 
    organization_id, create_time, update_time, create_user, update_user
) VALUES (
    '$TEST_CUSTOMER_ID',
    '$TEST_COMPANY_NAME',
    'admin',
    UNIX_TIMESTAMP()*1000,
    0,
    'default_org',
    UNIX_TIMESTAMP()*1000,
    UNIX_TIMESTAMP()*1000,
    'admin',
    'admin'
);

-- 插入企业档案 (测试日期格式)
INSERT INTO enterprise_profile (
    id, customer_id, credit_code, company_name, legal_person,
    reg_capital, reg_date, staff_size, industry_name,
    province, city, address, status, source, last_sync_at,
    organization_id, create_time, update_time, create_user, update_user
) VALUES (
    '$TEST_PROFILE_ID',
    '$TEST_CUSTOMER_ID',
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
    'direct_test',
    UNIX_TIMESTAMP()*1000,
    'default_org',
    UNIX_TIMESTAMP()*1000,
    UNIX_TIMESTAMP()*1000,
    'admin',
    'admin'
);

-- 查询验证
SELECT 
    id, 
    company_name, 
    credit_code, 
    reg_date,
    DATE_FORMAT(reg_date, '%Y-%m-%d') as formatted_date
FROM enterprise_profile 
WHERE credit_code='$TEST_CREDIT_CODE';
SQL

INSERT_RESULT=$?

echo ""
if [ $INSERT_RESULT -eq 0 ]; then
    echo -e "${GREEN}✓ 数据库插入成功${NC}"
else
    echo -e "${RED}✗ 数据库插入失败 (退出码: $INSERT_RESULT)${NC}"
fi
echo ""

# 等待日志输出
echo -e "${YELLOW}等待日志输出 (3秒)...${NC}"
sleep 3
echo ""

# 分析日志
echo -e "${CYAN}=== 日志分析 ===${NC}"
if [ -s "$LOG_FILE" ]; then
    echo -e "${GREEN}✓ 捕获到日志${NC}"
    cat "$LOG_FILE"
else
    echo -e "${YELLOW}⚠ 未捕获到相关日志${NC}"
    echo -e "${BLUE}说明: 直接数据库插入不会触发后端 Service 层${NC}"
fi
echo ""

# 验证数据
echo -e "${CYAN}=== 数据验证 ===${NC}"
VERIFY_RESULT=$(docker exec cordys-mysql mysql -uroot -p123456 cordys_crm -e \
    "SELECT id, company_name, credit_code, reg_date FROM enterprise_profile WHERE credit_code='$TEST_CREDIT_CODE';" \
    2>/dev/null || echo "")

if [ -n "$VERIFY_RESULT" ] && echo "$VERIFY_RESULT" | grep -q "$TEST_CREDIT_CODE"; then
    echo -e "${GREEN}✓ 数据库中找到记录${NC}"
    echo "$VERIFY_RESULT"
    echo ""
    echo -e "${GREEN}✓✓✓ 数据库层面测试通过${NC}"
    echo -e "${BLUE}说明: 数据库可以正常存储日期类型${NC}"
else
    echo -e "${RED}✗ 数据库中未找到记录${NC}"
fi
echo ""

# 总结
echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}测试总结${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""
echo -e "测试方式: 直接数据库插入"
echo -e "测试数据: $TEST_COMPANY_NAME ($TEST_CREDIT_CODE)"
echo -e "日志文件: $LOG_FILE"
echo ""
echo -e "${YELLOW}注意:${NC}"
echo -e "1. 直接数据库插入不会触发后端 Service 层"
echo -e "2. 需要通过 API 或 Flutter 触发才能测试完整流程"
echo -e "3. 建议使用: ./scripts/monitor_import_realtime.sh"
echo ""
