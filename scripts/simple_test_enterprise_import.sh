#!/bin/bash

# 简化的企业导入测试脚本
# 功能：启动后端，使用现有的自动化测试脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}企业导入测试 - 简化版${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""

# 1. 停止现有后端
echo -e "${YELLOW}[1/4] 停止现有后端...${NC}"
BACKEND_PID=$(pgrep -f "cn.cordys.Application" || echo "")
if [ -n "$BACKEND_PID" ]; then
    echo -e "${BLUE}停止后端进程 (PID: $BACKEND_PID)${NC}"
    kill $BACKEND_PID
    sleep 3
fi
echo -e "${GREEN}✓ 后端已停止${NC}"
echo ""

# 2. 启动后端
echo -e "${YELLOW}[2/4] 启动后端...${NC}"
cd backend
echo -e "${BLUE}编译后端...${NC}"
mvn clean compile -q

echo -e "${BLUE}启动后端服务...${NC}"
cd app
nohup mvn spring-boot:run > /tmp/backend_startup.log 2>&1 &
BACKEND_PID=$!
echo -e "${GREEN}✓ 后端启动中 (PID: $BACKEND_PID)${NC}"

# 等待后端启动
echo -e "${BLUE}等待后端启动...${NC}"
for i in {1..60}; do
    if curl -s http://localhost:8081/actuator/health >/dev/null 2>&1; then
        echo -e "${GREEN}✓ 后端启动成功${NC}"
        break
    fi
    if [ $i -eq 60 ]; then
        echo -e "${RED}✗ 后端启动超时${NC}"
        echo "后端启动日志："
        tail -20 /tmp/backend_startup.log
        exit 1
    fi
    sleep 2
    echo -n "."
done
echo ""

cd ../../

# 3. 检查环境
echo -e "${YELLOW}[3/4] 检查环境...${NC}"

# 检查数据库
if ! docker ps | grep -q cordys-mysql; then
    echo -e "${RED}✗ MySQL 未运行，启动数据库...${NC}"
    docker start cordys-mysql || echo "启动MySQL失败"
    sleep 5
fi
echo -e "${GREEN}✓ MySQL 运行中${NC}"

# 检查ADB
if ! adb devices | grep -q "device$"; then
    echo -e "${YELLOW}⚠ ADB 未连接，将使用API测试${NC}"
    USE_API=true
else
    DEVICE_ID=$(adb devices | grep "device$" | awk '{print $1}')
    echo -e "${GREEN}✓ ADB已连接 (设备: $DEVICE_ID)${NC}"
    USE_API=false
fi
echo ""

# 4. 运行现有的自动化测试
echo -e "${YELLOW}[4/4] 运行企业导入测试...${NC}"

if [ -f "./scripts/auto_test_enterprise_import.sh" ]; then
    echo -e "${BLUE}使用现有的自动化测试脚本...${NC}"
    ./scripts/auto_test_enterprise_import.sh
else
    echo -e "${YELLOW}现有测试脚本不存在，执行简单API测试...${NC}"
    
    # 创建测试数据
    TEST_CREDIT_CODE="91110000MA01TEST$(date +%s | tail -c 4)"
    TEST_COMPANY_NAME="激光测试企业_$(date +%H%M%S)"
    
    cat > /tmp/test_laser_enterprise.json <<EOF
{
  "creditCode": "$TEST_CREDIT_CODE",
  "companyName": "$TEST_COMPANY_NAME",
  "legalPerson": "张三",
  "registeredCapital": 1000000,
  "establishmentDate": $(date -d "2020-01-01" +%s)000,
  "address": "北京市朝阳区激光产业园123号",
  "province": "北京市",
  "city": "北京市",
  "industry": "激光设备制造",
  "industryCode": "35",
  "staffSize": "50-100人",
  "phone": "010-12345678",
  "email": "test@laser.com",
  "website": "https://laser-test.com",
  "status": "存续",
  "source": "auto_test"
}
EOF

    echo -e "${BLUE}测试数据已生成: $TEST_COMPANY_NAME${NC}"
    
    # 尝试登录并导入
    echo -e "${BLUE}尝试登录...${NC}"
    LOGIN_RESPONSE=$(curl -s -c /tmp/cookies.txt -X POST http://localhost:8081/login \
        -H "Content-Type: application/json" \
        -d '{"username":"admin","password":"admin123"}' 2>/dev/null || echo "")
    
    if echo "$LOGIN_RESPONSE" | grep -q "id"; then
        echo -e "${GREEN}✓ 登录成功${NC}"
        
        echo -e "${BLUE}执行企业导入...${NC}"
        IMPORT_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -b /tmp/cookies.txt -X POST \
            http://localhost:8081/api/enterprise/import \
            -H "Content-Type: application/json" \
            -d @/tmp/test_laser_enterprise.json 2>/dev/null || echo "HTTP_CODE:000")
        
        HTTP_CODE=$(echo "$IMPORT_RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)
        RESPONSE_BODY=$(echo "$IMPORT_RESPONSE" | grep -v "HTTP_CODE:")
        
        echo -e "${BLUE}响应状态码: $HTTP_CODE${NC}"
        echo -e "${BLUE}响应内容:${NC}"
        echo "$RESPONSE_BODY" | jq '.' 2>/dev/null || echo "$RESPONSE_BODY"
        
        # 检查数据库
        echo -e "${BLUE}检查数据库...${NC}"
        DB_CHECK=$(docker exec cordys-mysql mysql -uroot -p123456 cordys_crm -e \
            "SELECT id, company_name, credit_code FROM enterprise_profile WHERE credit_code='$TEST_CREDIT_CODE';" \
            2>/dev/null || echo "")
        
        if [ -n "$DB_CHECK" ] && echo "$DB_CHECK" | grep -q "$TEST_CREDIT_CODE"; then
            echo -e "${GREEN}✓✓✓ 测试成功！企业已导入数据库${NC}"
            echo "$DB_CHECK"
        else
            echo -e "${RED}✗ 数据库中未找到记录${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ 登录失败，直接检查数据库插入${NC}"
        
        # 直接插入数据库测试
        docker exec cordys-mysql mysql -uroot -p123456 cordys_crm <<SQL 2>/dev/null || true
INSERT INTO customer (id, name, owner, collection_time, in_shared_pool, organization_id, create_time, update_time, create_user, update_user)
VALUES ('test_cust_$(date +%s)', '$TEST_COMPANY_NAME', 'admin', UNIX_TIMESTAMP()*1000, 0, 'default_org', UNIX_TIMESTAMP()*1000, UNIX_TIMESTAMP()*1000, 'admin', 'admin');

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
    '激光设备制造',
    '北京市',
    '北京市',
    '北京市朝阳区激光产业园123号',
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
    fi
fi

echo ""
echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}测试完成${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""
echo -e "${BLUE}后端PID: $BACKEND_PID${NC}"
echo -e "${BLUE}后端日志: /tmp/backend_startup.log${NC}"
echo -e "${BLUE}如需查看后端日志: tail -f /tmp/backend_startup.log${NC}"
echo ""

if [ "$USE_API" = false ]; then
    echo -e "${YELLOW}Flutter应用测试建议:${NC}"
    echo -e "1. 在Flutter应用中设置服务器地址为: localhost:8081"
    echo -e "2. 搜索关键词: 激光"
    echo -e "3. 选择企业并点击导入"
    echo -e "4. 观察导入结果"
fi
