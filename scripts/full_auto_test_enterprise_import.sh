#!/bin/bash

# 完整自动化企业导入测试脚本
# 功能：重启后端和Flutter，设置服务器地址，搜索"激光行业"，全选导入，抓取日志分析错误

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
echo -e "${CYAN}完整自动化企业导入测试${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""

# 创建日志目录
mkdir -p logs
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="logs/full_auto_test_${TIMESTAMP}.log"
BACKEND_LOG="logs/backend_${TIMESTAMP}.log"
FLUTTER_LOG="logs/flutter_${TIMESTAMP}.log"

echo -e "${GREEN}✓ 日志目录: logs/${NC}"
echo -e "${GREEN}✓ 测试日志: $LOG_FILE${NC}"
echo ""

# 清理函数
cleanup() {
    echo ""
    echo -e "${YELLOW}清理监控进程...${NC}"
    [ -n "$BACKEND_MONITOR_PID" ] && kill $BACKEND_MONITOR_PID 2>/dev/null || true
    [ -n "$FLUTTER_MONITOR_PID" ] && kill $FLUTTER_MONITOR_PID 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# 1. 停止现有进程
echo -e "${YELLOW}[1/8] 停止现有进程...${NC}"

# 停止后端
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

# 停止Flutter
FLUTTER_PID=$(pgrep -f "flutter.*run" || echo "")
if [ -n "$FLUTTER_PID" ]; then
    echo -e "${BLUE}停止Flutter进程 (PID: $FLUTTER_PID)${NC}"
    kill $FLUTTER_PID
    sleep 2
fi

echo -e "${GREEN}✓ 现有进程已停止${NC}"
echo ""

# 2. 启动后端
echo -e "${YELLOW}[2/8] 启动后端...${NC}"

cd backend
echo -e "${BLUE}编译后端...${NC}"
mvn clean compile -q

echo -e "${BLUE}启动后端服务...${NC}"
cd app
nohup mvn spring-boot:run > "$BACKEND_LOG" 2>&1 &
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

# 3. 检查ADB连接
echo -e "${YELLOW}[3/8] 检查ADB连接...${NC}"

if ! adb devices | grep -q "device$"; then
    echo -e "${RED}✗ ADB未连接，请连接Android设备${NC}"
    exit 1
fi

DEVICE_ID=$(adb devices | grep "device$" | awk '{print $1}')
echo -e "${GREEN}✓ ADB已连接 (设备: $DEVICE_ID)${NC}"
echo ""

# 4. 启动Flutter应用
echo -e "${YELLOW}[4/8] 启动Flutter应用...${NC}"

cd mobile/cordyscrm_flutter

# 清理Flutter缓存
echo -e "${BLUE}清理Flutter缓存...${NC}"
flutter clean > /dev/null 2>&1
flutter pub get > /dev/null 2>&1

echo -e "${BLUE}启动Flutter应用...${NC}"
nohup flutter run --debug > "$FLUTTER_LOG" 2>&1 &
FLUTTER_PID=$!

echo -e "${GREEN}✓ Flutter启动中 (PID: $FLUTTER_PID)${NC}"

# 等待Flutter启动
echo -e "${BLUE}等待Flutter应用启动...${NC}"
for i in {1..60}; do
    if adb shell "dumpsys activity activities" | grep -q "cordyscrm"; then
        echo -e "${GREEN}✓ Flutter应用启动成功${NC}"
        break
    fi
    if [ $i -eq 60 ]; then
        echo -e "${RED}✗ Flutter应用启动超时${NC}"
        exit 1
    fi
    sleep 2
    echo -n "."
done
echo ""

cd ../..

# 5. 设置服务器地址
echo -e "${YELLOW}[5/8] 设置服务器地址为192.168.1.226...${NC}"

# 等待应用完全加载
sleep 5

# 通过ADB设置服务器地址
echo -e "${BLUE}通过ADB设置服务器地址...${NC}"

# 方法1: 通过UI自动化设置
adb shell input keyevent KEYCODE_MENU
sleep 1
adb shell input tap 500 1000  # 点击设置按钮（需要根据实际UI调整坐标）
sleep 2
adb shell input tap 500 600   # 点击服务器设置
sleep 1
adb shell input tap 500 400   # 点击服务器地址输入框
sleep 1
adb shell input keyevent KEYCODE_CTRL_A  # 全选
adb shell input text "192.168.1.226:8081"
sleep 1
adb shell input keyevent KEYCODE_ENTER
sleep 2

echo -e "${GREEN}✓ 服务器地址设置完成${NC}"
echo ""

# 6. 启动日志监控
echo -e "${YELLOW}[6/8] 启动日志监控...${NC}"

# 监控后端日志
tail -f "$BACKEND_LOG" | \
    grep --line-buffered -E "企业|enterprise|import|MyBatis|SQL|Exception|Error|Caused by|insertWithDateConversion|准备插入|插入.*成功|插入.*失败|激光" \
    > "${BACKEND_LOG}.filtered" &
BACKEND_MONITOR_PID=$!

# 监控Flutter日志
adb logcat -c
adb logcat -v time | \
    grep --line-buffered -E "cordyscrm|flutter|enterprise|import|batch|error|exception|激光|search" \
    > "${FLUTTER_LOG}.filtered" &
FLUTTER_MONITOR_PID=$!

echo -e "${GREEN}✓ 日志监控已启动${NC}"
echo ""

# 7. 执行企业搜索和导入
echo -e "${YELLOW}[7/8] 执行企业搜索和导入...${NC}"

# 等待应用稳定
sleep 3

echo -e "${BLUE}步骤1: 导航到企业搜索页面${NC}"
# 点击企业搜索菜单（需要根据实际UI调整坐标）
adb shell input tap 200 800  # 点击企业搜索菜单
sleep 2

echo -e "${BLUE}步骤2: 搜索"激光行业"${NC}"
# 点击搜索框
adb shell input tap 500 300
sleep 1
# 输入搜索关键词
adb shell input text "激光行业"
sleep 1
# 点击搜索按钮
adb shell input tap 700 300
sleep 3

echo -e "${BLUE}步骤3: 等待搜索结果加载${NC}"
# 等待搜索结果
for i in {1..10}; do
    if adb shell "dumpsys activity activities" | grep -q "搜索完成"; then
        echo -e "${GREEN}✓ 搜索完成${NC}"
        break
    fi
    sleep 2
    echo -n "."
done
echo ""

echo -e "${BLUE}步骤4: 全选企业${NC}"
# 点击全选按钮
adb shell input tap 100 400
sleep 1

echo -e "${BLUE}步骤5: 执行批量导入${NC}"
# 点击导入按钮
adb shell input tap 600 1000
sleep 2

# 确认导入
adb shell input tap 400 600  # 点击确认按钮
sleep 1

echo -e "${GREEN}✓ 导入操作已触发${NC}"
echo ""

# 8. 等待并分析结果
echo -e "${YELLOW}[8/8] 等待导入完成并分析结果...${NC}"

echo -e "${BLUE}等待导入处理 (30秒)...${NC}"
for i in {1..30}; do
    echo -n "."
    sleep 1
done
echo ""

# 分析后端日志
echo -e "${CYAN}=== 后端日志分析 ===${NC}"
if [ -s "${BACKEND_LOG}.filtered" ]; then
    echo -e "${GREEN}✓ 捕获到后端日志${NC}"
    echo ""
    
    # 显示最近的日志
    echo -e "${BLUE}最近的后端日志:${NC}"
    tail -20 "${BACKEND_LOG}.filtered"
    echo ""
    
    # 查找SQL执行
    if grep -q "### SQL:" "${BACKEND_LOG}.filtered"; then
        echo -e "${GREEN}✓ 发现SQL执行日志${NC}"
        grep "### SQL:" "${BACKEND_LOG}.filtered" | tail -3
        echo ""
    fi
    
    # 查找成功标志
    if grep -q "插入企业档案成功" "${BACKEND_LOG}.filtered"; then
        echo -e "${GREEN}✓✓✓ 发现成功导入！${NC}"
        grep "插入企业档案成功" "${BACKEND_LOG}.filtered"
        echo ""
    fi
    
    # 查找错误
    if grep -q -E "Exception|Error|失败" "${BACKEND_LOG}.filtered"; then
        echo -e "${RED}✗ 发现错误${NC}"
        echo ""
        echo -e "${YELLOW}错误详情:${NC}"
        grep -A 5 -B 2 -E "Exception|Error|失败" "${BACKEND_LOG}.filtered" | tail -20
        echo ""
        
        # 查找完整错误堆栈
        if grep -q "Caused by:" "${BACKEND_LOG}.filtered"; then
            echo -e "${YELLOW}完整错误堆栈:${NC}"
            grep -A 10 "Caused by:" "${BACKEND_LOG}.filtered"
            echo ""
        fi
    fi
else
    echo -e "${YELLOW}⚠ 未捕获到后端日志${NC}"
fi

# 分析Flutter日志
echo -e "${CYAN}=== Flutter 日志分析 ===${NC}"
if [ -s "${FLUTTER_LOG}.filtered" ]; then
    echo -e "${GREEN}✓ 捕获到Flutter日志${NC}"
    echo ""
    
    echo -e "${BLUE}最近的Flutter日志:${NC}"
    tail -15 "${FLUTTER_LOG}.filtered"
    echo ""
    
    if grep -q -E "error|exception|失败" "${FLUTTER_LOG}.filtered"; then
        echo -e "${RED}✗ Flutter端发现错误${NC}"
        grep -i -E "error|exception|失败" "${FLUTTER_LOG}.filtered" | tail -5
        echo ""
    fi
    
    if grep -q "导入成功" "${FLUTTER_LOG}.filtered"; then
        echo -e "${GREEN}✓✓✓ Flutter显示导入成功${NC}"
        grep "导入成功" "${FLUTTER_LOG}.filtered"
        echo ""
    fi
else
    echo -e "${YELLOW}⚠ 未捕获到Flutter日志${NC}"
fi

# 检查数据库
echo -e "${CYAN}=== 数据库验证 ===${NC}"
echo -e "${BLUE}检查最近导入的企业记录...${NC}"

DB_CHECK=$(docker exec cordys-mysql mysql -uroot -p123456 cordys_crm -e \
    "SELECT id, company_name, credit_code, reg_date, create_time FROM enterprise_profile 
     WHERE industry_name LIKE '%激光%' OR company_name LIKE '%激光%' 
     ORDER BY create_time DESC LIMIT 5;" \
    2>/dev/null || echo "")

if [ -n "$DB_CHECK" ] && echo "$DB_CHECK" | grep -q "激光"; then
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
fi
echo ""

# 总结报告
echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}测试总结报告${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""

echo -e "${PURPLE}测试配置:${NC}"
echo -e "- 服务器地址: 192.168.1.226:8081"
echo -e "- 搜索关键词: 激光行业"
echo -e "- 操作类型: 全选批量导入"
echo -e "- 设备ID: $DEVICE_ID"
echo ""

echo -e "${PURPLE}日志文件:${NC}"
echo -e "- 后端日志: $BACKEND_LOG"
echo -e "- 后端过滤日志: ${BACKEND_LOG}.filtered"
echo -e "- Flutter日志: $FLUTTER_LOG"
echo -e "- Flutter过滤日志: ${FLUTTER_LOG}.filtered"
echo ""

echo -e "${PURPLE}进程信息:${NC}"
echo -e "- 后端PID: $BACKEND_PID"
echo -e "- Flutter PID: $FLUTTER_PID"
echo ""

# 判断测试结果
SUCCESS_INDICATORS=0

if grep -q "插入企业档案成功" "${BACKEND_LOG}.filtered" 2>/dev/null; then
    SUCCESS_INDICATORS=$((SUCCESS_INDICATORS + 1))
fi

if echo "$DB_CHECK" | grep -q "激光" 2>/dev/null; then
    SUCCESS_INDICATORS=$((SUCCESS_INDICATORS + 1))
fi

if grep -q "导入成功" "${FLUTTER_LOG}.filtered" 2>/dev/null; then
    SUCCESS_INDICATORS=$((SUCCESS_INDICATORS + 1))
fi

echo -e "${PURPLE}测试结果:${NC}"
if [ $SUCCESS_INDICATORS -ge 2 ]; then
    echo -e "${GREEN}✓✓✓ 测试通过！ (成功指标: $SUCCESS_INDICATORS/3)${NC}"
    echo ""
    echo -e "${GREEN}导入操作成功完成，激光行业企业已成功导入到CRM系统${NC}"
    exit 0
else
    echo -e "${RED}✗✗✗ 测试失败 (成功指标: $SUCCESS_INDICATORS/3)${NC}"
    echo ""
    echo -e "${YELLOW}问题分析建议:${NC}"
    echo -e "1. 查看完整后端日志: cat $BACKEND_LOG"
    echo -e "2. 查看后端过滤日志: cat ${BACKEND_LOG}.filtered"
    echo -e "3. 查看Flutter日志: cat ${FLUTTER_LOG}.filtered"
    echo -e "4. 检查错误堆栈中的'Caused by'部分"
    echo -e "5. 验证数据库约束: docker exec cordys-mysql mysql -uroot -p123456 cordys_crm -e 'SHOW CREATE TABLE enterprise_profile;'"
    echo ""
    
    # 显示关键错误信息
    if [ -s "${BACKEND_LOG}.filtered" ]; then
        echo -e "${YELLOW}关键错误信息:${NC}"
        grep -E "Exception|Error|失败|Caused by" "${BACKEND_LOG}.filtered" | tail -10
    fi
    
    exit 1
fi
