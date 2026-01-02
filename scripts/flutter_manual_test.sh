#!/bin/bash

# Flutter应用企业导入测试脚本
# 功能：启动Flutter应用，设置服务器地址，手动指导测试

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
echo -e "${CYAN}Flutter企业导入测试${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""

# 创建日志目录
mkdir -p logs
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKEND_LOG="logs/backend_flutter_${TIMESTAMP}.log"
FLUTTER_LOG="logs/flutter_app_${TIMESTAMP}.log"

# 清理函数
cleanup() {
    echo ""
    echo -e "${YELLOW}清理监控进程...${NC}"
    [ -n "$BACKEND_MONITOR_PID" ] && kill $BACKEND_MONITOR_PID 2>/dev/null || true
    [ -n "$FLUTTER_MONITOR_PID" ] && kill $FLUTTER_MONITOR_PID 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# 1. 检查后端状态
echo -e "${YELLOW}[1/5] 检查后端状态...${NC}"
BACKEND_PID=$(pgrep -f "cn.cordys.Application" || echo "")
if [ -z "$BACKEND_PID" ]; then
    echo -e "${RED}✗ 后端未运行，请先启动后端${NC}"
    exit 1
fi

if ! curl -s http://localhost:8081/actuator/health >/dev/null 2>&1; then
    echo -e "${RED}✗ 后端健康检查失败${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 后端运行正常 (PID: $BACKEND_PID)${NC}"
echo ""

# 2. 检查ADB连接
echo -e "${YELLOW}[2/5] 检查ADB连接...${NC}"
if ! adb devices | grep -q "device$"; then
    echo -e "${RED}✗ ADB未连接，请连接Android设备${NC}"
    exit 1
fi

DEVICE_ID=$(adb devices | grep "device$" | awk '{print $1}')
echo -e "${GREEN}✓ ADB已连接 (设备: $DEVICE_ID)${NC}"
echo ""

# 3. 启动Flutter应用
echo -e "${YELLOW}[3/5] 启动Flutter应用...${NC}"

# 检查是否已有Flutter应用运行
if adb shell "dumpsys activity activities" | grep -q "cordyscrm"; then
    echo -e "${BLUE}Flutter应用已在运行，重启应用...${NC}"
    adb shell am force-stop com.example.cordyscrm_flutter
    sleep 2
fi

cd mobile/cordyscrm_flutter

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
        echo "Flutter启动日志："
        tail -20 "$FLUTTER_LOG"
        exit 1
    fi
    sleep 2
    echo -n "."
done
echo ""

cd ../../

# 4. 启动日志监控
echo -e "${YELLOW}[4/5] 启动日志监控...${NC}"

# 监控后端日志
tail -f /proc/$BACKEND_PID/fd/1 2>/dev/null | \
    grep --line-buffered -E "企业|enterprise|import|MyBatis|SQL|Exception|Error|Caused by|insertWithDateConversion|准备插入|插入.*成功|插入.*失败|激光" \
    > "$BACKEND_LOG" &
BACKEND_MONITOR_PID=$!

# 监控Flutter日志
adb logcat -c
adb logcat -v time | \
    grep --line-buffered -E "cordyscrm|flutter|enterprise|import|batch|error|exception|激光|search|导入" \
    > "${FLUTTER_LOG}.logcat" &
FLUTTER_MONITOR_PID=$!

echo -e "${GREEN}✓ 日志监控已启动${NC}"
echo ""

# 5. 手动测试指导
echo -e "${YELLOW}[5/5] 手动测试指导${NC}"
echo ""

echo -e "${PURPLE}请按照以下步骤进行测试:${NC}"
echo ""

echo -e "${CYAN}步骤1: 设置服务器地址${NC}"
echo -e "1. 在Flutter应用中找到设置页面"
echo -e "2. 设置服务器地址为: ${GREEN}192.168.1.226:8081${NC}"
echo -e "3. 保存设置"
echo ""

echo -e "${CYAN}步骤2: 登录系统${NC}"
echo -e "1. 用户名: ${GREEN}admin${NC}"
echo -e "2. 密码: ${GREEN}admin123${NC}"
echo ""

echo -e "${CYAN}步骤3: 企业搜索${NC}"
echo -e "1. 导航到企业搜索页面"
echo -e "2. 搜索关键词: ${GREEN}激光行业${NC}"
echo -e "3. 等待搜索结果加载"
echo ""

echo -e "${CYAN}步骤4: 批量导入${NC}"
echo -e "1. 点击${GREEN}全选${NC}按钮"
echo -e "2. 点击${GREEN}导入${NC}按钮"
echo -e "3. 确认导入操作"
echo ""

echo -e "${CYAN}步骤5: 观察结果${NC}"
echo -e "1. 查看导入进度提示"
echo -e "2. 等待导入完成"
echo -e "3. 检查导入结果"
echo ""

echo -e "${PURPLE}测试完成后，按 Enter 键查看日志分析...${NC}"
read -r

# 分析日志
echo ""
echo -e "${CYAN}=== 日志分析 ===${NC}"
echo ""

# 分析后端日志
echo -e "${BLUE}后端日志分析:${NC}"
if [ -s "$BACKEND_LOG" ]; then
    echo -e "${GREEN}✓ 捕获到后端日志${NC}"
    
    # 显示最近的日志
    echo -e "${YELLOW}最近的后端日志:${NC}"
    tail -20 "$BACKEND_LOG"
    echo ""
    
    # 查找SQL执行
    if grep -q "### SQL:" "$BACKEND_LOG"; then
        echo -e "${GREEN}✓ 发现SQL执行日志${NC}"
        grep "### SQL:" "$BACKEND_LOG" | tail -3
        echo ""
    fi
    
    # 查找成功标志
    if grep -q "插入企业档案成功" "$BACKEND_LOG"; then
        echo -e "${GREEN}✓✓✓ 发现成功导入！${NC}"
        grep "插入企业档案成功" "$BACKEND_LOG"
        echo ""
    fi
    
    # 查找错误
    if grep -q -E "Exception|Error|失败" "$BACKEND_LOG"; then
        echo -e "${RED}✗ 发现错误${NC}"
        echo ""
        echo -e "${YELLOW}错误详情:${NC}"
        grep -A 5 -B 2 -E "Exception|Error|失败" "$BACKEND_LOG" | tail -20
        echo ""
        
        # 查找完整错误堆栈
        if grep -q "Caused by:" "$BACKEND_LOG"; then
            echo -e "${YELLOW}完整错误堆栈:${NC}"
            grep -A 10 "Caused by:" "$BACKEND_LOG"
            echo ""
        fi
    fi
else
    echo -e "${YELLOW}⚠ 未捕获到后端日志${NC}"
fi

# 分析Flutter日志
echo -e "${BLUE}Flutter日志分析:${NC}"
if [ -s "${FLUTTER_LOG}.logcat" ]; then
    echo -e "${GREEN}✓ 捕获到Flutter日志${NC}"
    
    echo -e "${YELLOW}最近的Flutter日志:${NC}"
    tail -15 "${FLUTTER_LOG}.logcat"
    echo ""
    
    if grep -q -E "error|exception|失败" "${FLUTTER_LOG}.logcat"; then
        echo -e "${RED}✗ Flutter端发现错误${NC}"
        grep -i -E "error|exception|失败" "${FLUTTER_LOG}.logcat" | tail -5
        echo ""
    fi
    
    if grep -q "导入成功" "${FLUTTER_LOG}.logcat"; then
        echo -e "${GREEN}✓✓✓ Flutter显示导入成功${NC}"
        grep "导入成功" "${FLUTTER_LOG}.logcat"
        echo ""
    fi
else
    echo -e "${YELLOW}⚠ 未捕获到Flutter日志${NC}"
fi

# 检查数据库
echo -e "${BLUE}数据库验证:${NC}"
echo -e "${YELLOW}检查激光行业企业记录...${NC}"

DB_CHECK=$(docker exec cordys-mysql mysql -uroot -proot cordys_crm -e \
    "SELECT id, company_name, credit_code, reg_date, create_time FROM enterprise_profile 
     WHERE industry_name LIKE '%激光%' OR company_name LIKE '%激光%' 
     ORDER BY create_time DESC LIMIT 5;" \
    2>/dev/null || echo "")

if [ -n "$DB_CHECK" ] && echo "$DB_CHECK" | grep -q "激光"; then
    echo -e "${GREEN}✓✓✓ 数据库中找到激光行业企业记录${NC}"
    echo "$DB_CHECK"
    echo ""
    
    # 统计导入数量
    COUNT=$(docker exec cordys-mysql mysql -uroot -proot cordys_crm -e \
        "SELECT COUNT(*) as count FROM enterprise_profile 
         WHERE (industry_name LIKE '%激光%' OR company_name LIKE '%激光%') 
         AND create_time > UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 1 HOUR))*1000;" \
        2>/dev/null | tail -1)
    
    echo -e "${GREEN}✓ 最近1小时内导入的激光企业数量: $COUNT${NC}"
else
    echo -e "${YELLOW}⚠ 数据库中未找到激光行业企业记录${NC}"
    
    # 显示最近的企业记录
    echo -e "${BLUE}最近导入的企业记录:${NC}"
    RECENT_CHECK=$(docker exec cordys-mysql mysql -uroot -proot cordys_crm -e \
        "SELECT id, company_name, credit_code, create_time FROM enterprise_profile 
         ORDER BY create_time DESC LIMIT 3;" \
        2>/dev/null || echo "")
    echo "$RECENT_CHECK"
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
echo -e "- Flutter应用日志: $FLUTTER_LOG"
echo -e "- Flutter Logcat: ${FLUTTER_LOG}.logcat"
echo ""

echo -e "${PURPLE}进程信息:${NC}"
echo -e "- 后端PID: $BACKEND_PID"
echo -e "- Flutter PID: $FLUTTER_PID"
echo ""

# 判断测试结果
SUCCESS_INDICATORS=0

if grep -q "插入企业档案成功" "$BACKEND_LOG" 2>/dev/null; then
    SUCCESS_INDICATORS=$((SUCCESS_INDICATORS + 1))
fi

if echo "$DB_CHECK" | grep -q "激光" 2>/dev/null; then
    SUCCESS_INDICATORS=$((SUCCESS_INDICATORS + 1))
fi

if grep -q "导入成功" "${FLUTTER_LOG}.logcat" 2>/dev/null; then
    SUCCESS_INDICATORS=$((SUCCESS_INDICATORS + 1))
fi

echo -e "${PURPLE}测试结果:${NC}"
if [ $SUCCESS_INDICATORS -ge 2 ]; then
    echo -e "${GREEN}✓✓✓ 测试通过！ (成功指标: $SUCCESS_INDICATORS/3)${NC}"
    echo ""
    echo -e "${GREEN}激光行业企业导入测试成功完成！${NC}"
else
    echo -e "${YELLOW}⚠ 测试部分成功 (成功指标: $SUCCESS_INDICATORS/3)${NC}"
    echo ""
    echo -e "${YELLOW}建议检查:${NC}"
    echo -e "1. 查看完整后端日志: cat $BACKEND_LOG"
    echo -e "2. 查看Flutter应用日志: cat $FLUTTER_LOG"
    echo -e "3. 查看Flutter Logcat: cat ${FLUTTER_LOG}.logcat"
    echo -e "4. 检查网络连接和服务器地址设置"
    echo -e "5. 确认登录状态和权限"
fi

echo ""
echo -e "${BLUE}测试完成！日志文件已保存，可随时查看分析。${NC}"
