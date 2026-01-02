#!/bin/bash

# 后端企业导入测试脚本
# 功能：重启后端，直接测试企业导入API，抓取日志分析错误

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}后端企业导入测试${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""

# 创建日志目录
mkdir -p logs
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKEND_LOG="logs/backend_${TIMESTAMP}.log"

echo -e "${GREEN}✓ 后端日志文件: $BACKEND_LOG${NC}"
echo ""

# 1. 停止现有后端进程
echo -e "${YELLOW}[1/5] 停止现有后端进程...${NC}"

BACKEND_PID=$(pgrep -f "cn.cordys.Application" || echo "")
if [ -n "$BACKEND_PID" ]; then
    echo -e "${BLUE}停止后端进程 (PID: $BACKEND_PID)${NC}"
    kill $BACKEND_PID
    sleep 3
    # 强制杀死如果还在运行
    if kill -0 $BACKEND_PID 2>/dev/null; then
        kill -9 $BACKEND_PID
        sleep 2
    fi
fi

echo -e "${GREEN}✓ 现有后端进程已停止${NC}"
echo ""

# 2. 启动后端
echo -e "${YELLOW}[2/5] 启动后端...${NC}"

cd backend
echo -e "${BLUE}编译后端...${NC}"
mvn clean compile -q -DskipTests

echo -e "${BLUE}启动后端服务...${NC}"
cd app
nohup mvn spring-boot:run -DskipTests > "../../$BACKEND_LOG" 2>&1 &
BACKEND_PID=$!

echo -e "${GREEN}✓ 后端启动中 (PID: $BACKEND_PID)${NC}"

# 等待后端启动
echo -e "${BLUE}等待后端启动...${NC}"
for i in {1..30}; do
    if curl -s http://localhost:8081/actuator/health >/dev/null 2>&1; then
        echo -e "${GREEN}✓ 后端启动成功${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}✗ 后端启动超时${NC}"
        exit 1
    fi
    sleep 2
    echo -n "."
done
echo ""

cd ../..

# 3. 启动日志监控
echo -e "${YELLOW}[3/5] 启动日志监控...${NC}"

# 启动后端日志监控
tail -f "$BACKEND_LOG" | \
    grep --line-buffered -E "企业|enterprise|import|MyBatis|SQL|Exception|Error|Caused by|激光|批量导入|insertWithDateConversion|准备插入|插入.*成功|插入.*失败" \
    > "${BACKEND_LOG}.filtered" &
BACKEND_MONITOR_PID=$!

echo -e "${GREEN}✓ 日志监控已启动${NC}"
echo ""

# 清理函数
cleanup() {
    echo ""
    echo -e "${YELLOW}清理监控进程...${NC}"
    [ -n "$BACKEND_MONITOR_PID" ] && kill $BACKEND_MONITOR_PID 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# 4. 模拟企业搜索和导入
echo -e "${YELLOW}[4/5] 模拟企业搜索和导入...${NC}"

# 等待后端完全启动
sleep 5

echo -e "${BLUE}步骤1: 模拟企业搜索API调用${NC}"

# 构造搜索请求
SEARCH_DATA='{
  "keyword": "激光行业",
  "pageNum": 1,
  "pageSize": 20
}'

echo -e "${BLUE}发送搜索请求...${NC}"
SEARCH_RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "$SEARCH_DATA" \
  http://localhost:8081/api/enterprise/search || echo "搜索请求失败")

echo -e "${GREEN}✓ 搜索请求已发送${NC}"
echo -e "${BLUE}搜索响应: ${SEARCH_RESPONSE:0:200}...${NC}"
echo ""

# 等待搜索处理
sleep 3

echo -e "${BLUE}步骤2: 模拟批量导入API调用${NC}"

# 构造批量导入请求 - 使用测试数据
IMPORT_DATA='{
  "enterprises": [
    {
      "companyName": "激光科技有限公司",
      "creditCode": "91110000123456789A",
      "industryName": "激光设备制造",
      "regCapital": "1000万元",
      "regDate": "2020-01-01",
      "legalPerson": "张三",
      "address": "北京市海淀区中关村",
      "businessScope": "激光设备研发、生产、销售"
    },
    {
      "companyName": "光电激光技术公司",
      "creditCode": "91110000987654321B",
      "industryName": "激光技术服务",
      "regCapital": "500万元",
      "regDate": "2019-06-15",
      "legalPerson": "李四",
      "address": "上海市浦东新区张江",
      "businessScope": "激光技术开发、技术咨询"
    }
  ]
}'

echo -e "${BLUE}发送批量导入请求...${NC}"
IMPORT_RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "$IMPORT_DATA" \
  http://localhost:8081/api/enterprise/batch-import || echo "导入请求失败")

echo -e "${GREEN}✓ 批量导入请求已发送${NC}"
echo -e "${BLUE}导入响应: ${IMPORT_RESPONSE:0:200}...${NC}"
echo ""

# 等待导入处理
echo -e "${BLUE}等待导入处理完成 (15秒)...${NC}"
sleep 15

# 5. 分析结果
echo -e "${YELLOW}[5/5] 分析测试结果...${NC}"

# 分析后端日志
echo ""
echo -e "${CYAN}=== 后端日志分析 ===${NC}"
if [ -s "${BACKEND_LOG}.filtered" ]; then
    echo -e "${GREEN}✓ 捕获到后端日志${NC}"
    echo ""
    
    echo -e "${BLUE}最近的后端日志:${NC}"
    tail -30 "${BACKEND_LOG}.filtered"
    echo ""
    
    # 查找SQL执行
    if grep -q "### SQL:" "${BACKEND_LOG}.filtered"; then
        echo -e "${GREEN}✓ 发现SQL执行日志${NC}"
        echo -e "${BLUE}SQL执行记录:${NC}"
        grep "### SQL:" "${BACKEND_LOG}.filtered" | tail -5
        echo ""
    fi
    
    # 查找参数绑定
    if grep -q "### Parameters:" "${BACKEND_LOG}.filtered"; then
        echo -e "${GREEN}✓ 发现SQL参数绑定${NC}"
        echo -e "${BLUE}参数绑定记录:${NC}"
        grep "### Parameters:" "${BACKEND_LOG}.filtered" | tail -5
        echo ""
    fi
    
    # 查找成功标志
    if grep -q -E "插入.*成功|导入.*成功|SUCCESS" "${BACKEND_LOG}.filtered"; then
        echo -e "${GREEN}✓✓✓ 发现成功导入！${NC}"
        grep -E "插入.*成功|导入.*成功|SUCCESS" "${BACKEND_LOG}.filtered"
        echo ""
    fi
    
    # 查找错误
    if grep -q -E "Exception|Error|失败|ERROR" "${BACKEND_LOG}.filtered"; then
        echo -e "${RED}✗ 发现错误${NC}"
        echo ""
        echo -e "${YELLOW}错误详情:${NC}"
        grep -A 5 -B 2 -E "Exception|Error|失败|ERROR" "${BACKEND_LOG}.filtered" | tail -30
        echo ""
        
        # 查找完整错误堆栈
        if grep -q "Caused by:" "${BACKEND_LOG}.filtered"; then
            echo -e "${YELLOW}完整错误堆栈:${NC}"
            grep -A 10 "Caused by:" "${BACKEND_LOG}.filtered"
            echo ""
        fi
    fi
else
    echo -e "${YELLOW}⚠ 未捕获到过滤后的后端日志${NC}"
    echo -e "${BLUE}查看完整后端日志最后20行:${NC}"
    tail -20 "$BACKEND_LOG"
fi

# 检查数据库
echo ""
echo -e "${CYAN}=== 数据库验证 ===${NC}"
echo -e "${BLUE}检查最近导入的企业记录...${NC}"

DB_CHECK=$(docker exec cordys-mysql mysql -uroot -p123456 cordys_crm -e \
    "SELECT id, company_name, credit_code, reg_date, create_time FROM enterprise_profile 
     WHERE industry_name LIKE '%激光%' OR company_name LIKE '%激光%' 
     ORDER BY create_time DESC LIMIT 10;" \
    2>/dev/null || echo "数据库连接失败")

if echo "$DB_CHECK" | grep -q "激光"; then
    echo -e "${GREEN}✓✓✓ 数据库中找到激光行业企业记录${NC}"
    echo "$DB_CHECK"
    echo ""
    
    # 统计导入数量
    COUNT=$(docker exec cordys-mysql mysql -uroot -p123456 cordys_crm -e \
        "SELECT COUNT(*) as count FROM enterprise_profile 
         WHERE (industry_name LIKE '%激光%' OR company_name LIKE '%激光%') 
         AND create_time > UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 1 HOUR))*1000;" \
        2>/dev/null | tail -1)
    
    echo -e "${GREEN}✓ 最近1小时内导入的激光企业数量: $COUNT${NC}"
else
    echo -e "${YELLOW}⚠ 数据库中未找到激光行业企业记录${NC}"
    echo "$DB_CHECK"
    echo ""
    
    # 检查数据库表结构
    echo -e "${BLUE}检查enterprise_profile表结构:${NC}"
    docker exec cordys-mysql mysql -uroot -p123456 cordys_crm -e \
        "DESCRIBE enterprise_profile;" 2>/dev/null || echo "无法获取表结构"
fi
echo ""

# API响应分析
echo -e "${CYAN}=== API响应分析 ===${NC}"
echo -e "${BLUE}搜索API响应:${NC}"
echo "$SEARCH_RESPONSE" | jq . 2>/dev/null || echo "$SEARCH_RESPONSE"
echo ""

echo -e "${BLUE}导入API响应:${NC}"
echo "$IMPORT_RESPONSE" | jq . 2>/dev/null || echo "$IMPORT_RESPONSE"
echo ""

# 总结报告
echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}测试总结报告${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""

echo -e "${PURPLE}测试配置:${NC}"
echo -e "- 服务器地址: localhost:8081"
echo -e "- 搜索关键词: 激光行业"
echo -e "- 测试数据: 2个激光企业"
echo ""

echo -e "${PURPLE}日志文件:${NC}"
echo -e "- 后端日志: $BACKEND_LOG"
echo -e "- 后端过滤日志: ${BACKEND_LOG}.filtered"
echo ""

echo -e "${PURPLE}进程信息:${NC}"
echo -e "- 后端PID: $BACKEND_PID"
echo ""

# 判断测试结果
SUCCESS_INDICATORS=0

if grep -q -E "插入.*成功|导入.*成功|SUCCESS" "${BACKEND_LOG}.filtered" 2>/dev/null; then
    SUCCESS_INDICATORS=$((SUCCESS_INDICATORS + 1))
fi

if echo "$DB_CHECK" | grep -q "激光" 2>/dev/null; then
    SUCCESS_INDICATORS=$((SUCCESS_INDICATORS + 1))
fi

if echo "$IMPORT_RESPONSE" | grep -q -E "success|成功" 2>/dev/null; then
    SUCCESS_INDICATORS=$((SUCCESS_INDICATORS + 1))
fi

echo -e "${PURPLE}测试结果:${NC}"
if [ $SUCCESS_INDICATORS -ge 2 ]; then
    echo -e "${GREEN}✓✓✓ 测试通过！ (成功指标: $SUCCESS_INDICATORS/3)${NC}"
    echo ""
    echo -e "${GREEN}企业导入功能正常工作${NC}"
else
    echo -e "${RED}✗✗✗ 测试失败 (成功指标: $SUCCESS_INDICATORS/3)${NC}"
    echo ""
    echo -e "${YELLOW}问题分析建议:${NC}"
    echo -e "1. 查看完整后端日志: cat $BACKEND_LOG"
    echo -e "2. 查看后端过滤日志: cat ${BACKEND_LOG}.filtered"
    echo -e "3. 检查API端点是否正确"
    echo -e "4. 验证数据库约束和表结构"
    echo -e "5. 检查错误堆栈中的'Caused by'部分"
    echo ""
    
    # 显示关键错误信息
    if [ -s "${BACKEND_LOG}.filtered" ]; then
        echo -e "${YELLOW}关键错误信息:${NC}"
        grep -E "Exception|Error|失败|ERROR" "${BACKEND_LOG}.filtered" | tail -10
    fi
fi

echo ""
echo -e "${GREEN}测试完成！${NC}"
echo ""
echo -e "${BLUE}如需查看完整日志：${NC}"
echo -e "cat $BACKEND_LOG"
echo -e "cat ${BACKEND_LOG}.filtered"
