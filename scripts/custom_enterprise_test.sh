#!/bin/bash

# 自定义企业导入测试脚本
# 功能：重启后端和Flutter，设置服务器地址为192.168.1.226，搜索"激光行业"，全选导入，抓取日志

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}自定义企业导入测试${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""

# 创建日志目录
mkdir -p logs
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKEND_LOG="logs/backend_${TIMESTAMP}.log"
FLUTTER_LOG="logs/flutter_${TIMESTAMP}.log"

echo -e "${GREEN}✓ 日志文件: $BACKEND_LOG, $FLUTTER_LOG${NC}"
echo ""

# 1. 停止现有进程
echo -e "${YELLOW}[1/6] 停止现有进程...${NC}"

# 停止后端
BACKEND_PID=$(pgrep -f "cn.cordys.Application" || echo "")
if [ -n "$BACKEND_PID" ]; then
    echo -e "${BLUE}停止后端进程 (PID: $BACKEND_PID)${NC}"
    kill $BACKEND_PID
    sleep 3
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
echo -e "${YELLOW}[2/6] 启动后端...${NC}"

cd backend
echo -e "${BLUE}编译后端...${NC}"
mvn clean compile -q -DskipTests

echo -e "${BLUE}启动后端服务...${NC}"
cd app
nohup mvn spring-boot:run -DskipTests > "../$BACKEND_LOG" 2>&1 &
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
echo -e "${YELLOW}[3/6] 检查ADB连接...${NC}"

if ! adb devices | grep -q "device$"; then
    echo -e "${RED}✗ ADB未连接，请连接Android设备${NC}"
    exit 1
fi

DEVICE_ID=$(adb devices | grep "device$" | awk '{print $1}')
echo -e "${GREEN}✓ ADB已连接 (设备: $DEVICE_ID)${NC}"
echo ""

# 4. 启动Flutter应用
echo -e "${YELLOW}[4/6] 启动Flutter应用...${NC}"

cd mobile/cordyscrm_flutter

echo -e "${BLUE}获取Flutter依赖...${NC}"
flutter pub get > /dev/null 2>&1

echo -e "${BLUE}启动Flutter应用...${NC}"
nohup flutter run --debug -d $DEVICE_ID > "../../$FLUTTER_LOG" 2>&1 &
FLUTTER_PID=$!

echo -e "${GREEN}✓ Flutter启动中 (PID: $FLUTTER_PID)${NC}"

# 等待Flutter启动 - 检查logcat中的Flutter应用
echo -e "${BLUE}等待Flutter应用启动...${NC}"
for i in {1..45}; do
    # 检查Flutter进程是否还在运行
    if ! kill -0 $FLUTTER_PID 2>/dev/null; then
        echo -e "${RED}✗ Flutter进程意外退出${NC}"
        echo -e "${YELLOW}查看Flutter日志:${NC}"
        tail -20 "../../$FLUTTER_LOG"
        exit 1
    fi
    
    # 检查logcat中是否有Flutter应用的活动
    if adb logcat -d | grep -q "flutter\|cordyscrm" | tail -5 | grep -q "$(date +%m-%d)"; then
        echo -e "${GREEN}✓ Flutter应用启动成功${NC}"
        break
    fi
    
    if [ $i -eq 45 ]; then
        echo -e "${YELLOW}⚠ Flutter应用启动检测超时，继续执行...${NC}"
        break
    fi
    sleep 2
    echo -n "."
done
echo ""

cd ../..

# 5. 启动日志监控
echo -e "${YELLOW}[5/6] 启动日志监控...${NC}"

# 清理logcat缓存
adb logcat -c

# 启动后端日志监控
tail -f "$BACKEND_LOG" | \
    grep --line-buffered -E "企业|enterprise|import|MyBatis|SQL|Exception|Error|Caused by|激光|批量导入|insertWithDateConversion" \
    > "${BACKEND_LOG}.filtered" &
BACKEND_MONITOR_PID=$!

# 启动Flutter logcat监控
adb logcat -v time | \
    grep --line-buffered -E "flutter|cordyscrm|enterprise|import|batch|error|exception|激光|search|导入" \
    > "${FLUTTER_LOG}.logcat" &
FLUTTER_MONITOR_PID=$!

echo -e "${GREEN}✓ 日志监控已启动${NC}"
echo ""

# 清理函数
cleanup() {
    echo ""
    echo -e "${YELLOW}清理监控进程...${NC}"
    [ -n "$BACKEND_MONITOR_PID" ] && kill $BACKEND_MONITOR_PID 2>/dev/null || true
    [ -n "$FLUTTER_MONITOR_PID" ] && kill $FLUTTER_MONITOR_PID 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# 6. 手动操作指导
echo -e "${YELLOW}[6/6] 手动操作指导${NC}"
echo ""
echo -e "${CYAN}请在Android设备上手动执行以下操作：${NC}"
echo ""
echo -e "${GREEN}1. 打开CordysCRM应用${NC}"
echo -e "${GREEN}2. 进入设置页面，设置服务器地址为: 192.168.1.226:8081${NC}"
echo -e "${GREEN}3. 导航到企业搜索页面${NC}"
echo -e "${GREEN}4. 搜索关键词: 激光行业${NC}"
echo -e "${GREEN}5. 等待搜索结果加载完成${NC}"
echo -e "${GREEN}6. 点击全选按钮${NC}"
echo -e "${GREEN}7. 点击批量导入按钮${NC}"
echo -e "${GREEN}8. 确认导入操作${NC}"
echo ""
echo -e "${BLUE}操作完成后，按任意键继续分析日志...${NC}"
read -n 1 -s

echo ""
echo -e "${CYAN}=== 开始分析日志 ===${NC}"

# 等待导入处理
echo -e "${BLUE}等待导入处理完成 (20秒)...${NC}"
sleep 20

# 分析后端日志
echo ""
echo -e "${CYAN}=== 后端日志分析 ===${NC}"
if [ -s "${BACKEND_LOG}.filtered" ]; then
    echo -e "${GREEN}✓ 捕获到后端日志${NC}"
    echo ""
    
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
    if grep -q -E "插入.*成功|导入.*成功" "${BACKEND_LOG}.filtered"; then
        echo -e "${GREEN}✓✓✓ 发现成功导入！${NC}"
        grep -E "插入.*成功|导入.*成功" "${BACKEND_LOG}.filtered"
        echo ""
    fi
    
    # 查找错误
    if grep -q -E "Exception|Error|失败" "${BACKEND_LOG}.filtered"; then
        echo -e "${RED}✗ 发现错误${NC}"
        echo ""
        echo -e "${YELLOW}错误详情:${NC}"
        grep -A 5 -B 2 -E "Exception|Error|失败" "${BACKEND_LOG}.filtered" | tail -20
        echo ""
    fi
else
    echo -e "${YELLOW}⚠ 未捕获到后端日志${NC}"
    echo -e "${BLUE}查看完整后端日志:${NC}"
    tail -20 "$BACKEND_LOG"
fi

# 分析Flutter日志
echo ""
echo -e "${CYAN}=== Flutter 日志分析 ===${NC}"
if [ -s "${FLUTTER_LOG}.logcat" ]; then
    echo -e "${GREEN}✓ 捕获到Flutter logcat日志${NC}"
    echo ""
    
    echo -e "${BLUE}最近的Flutter logcat日志:${NC}"
    tail -15 "${FLUTTER_LOG}.logcat"
    echo ""
    
    if grep -q -E "error|exception|失败" "${FLUTTER_LOG}.logcat"; then
        echo -e "${RED}✗ Flutter端发现错误${NC}"
        grep -i -E "error|exception|失败" "${FLUTTER_LOG}.logcat" | tail -5
        echo ""
    fi
    
    if grep -q -E "导入成功|import.*success" "${FLUTTER_LOG}.logcat"; then
        echo -e "${GREEN}✓✓✓ Flutter显示导入成功${NC}"
        grep -E "导入成功|import.*success" "${FLUTTER_LOG}.logcat"
        echo ""
    fi
else
    echo -e "${YELLOW}⚠ 未捕获到Flutter logcat日志${NC}"
fi

# 检查Flutter应用日志文件
if [ -s "$FLUTTER_LOG" ]; then
    echo -e "${BLUE}Flutter应用日志文件:${NC}"
    tail -10 "$FLUTTER_LOG"
    echo ""
fi

# 检查数据库
echo -e "${CYAN}=== 数据库验证 ===${NC}"
echo -e "${BLUE}检查最近导入的企业记录...${NC}"

DB_CHECK=$(docker exec cordys-mysql mysql -uroot -p123456 cordys_crm -e \
    "SELECT id, company_name, credit_code, reg_date, create_time FROM enterprise_profile 
     WHERE industry_name LIKE '%激光%' OR company_name LIKE '%激光%' 
     ORDER BY create_time DESC LIMIT 5;" \
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
fi
echo ""

# 总结报告
echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}测试总结报告${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""

echo -e "${PURPLE}日志文件:${NC}"
echo -e "- 后端日志: $BACKEND_LOG"
echo -e "- 后端过滤日志: ${BACKEND_LOG}.filtered"
echo -e "- Flutter应用日志: $FLUTTER_LOG"
echo -e "- Flutter logcat日志: ${FLUTTER_LOG}.logcat"
echo ""

echo -e "${PURPLE}进程信息:${NC}"
echo -e "- 后端PID: $BACKEND_PID"
echo -e "- Flutter PID: $FLUTTER_PID"
echo ""

echo -e "${GREEN}测试完成！请查看上述日志分析结果。${NC}"
echo ""
echo -e "${BLUE}如需查看完整日志：${NC}"
echo -e "cat $BACKEND_LOG"
echo -e "cat ${BACKEND_LOG}.filtered"
echo -e "cat ${FLUTTER_LOG}.logcat"
