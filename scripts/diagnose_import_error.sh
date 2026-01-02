#!/bin/bash

# 企业导入错误诊断脚本
# 快速诊断导入失败的根本原因

set -e

echo "========================================="
echo "企业导入错误诊断（增强版）"
echo "========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 1. 检查后端日志中的错误
echo -e "${YELLOW}[1/6] 检查后端日志中的错误...${NC}"
echo ""

# 检查多个可能的日志位置
LOG_FILES=(
    "logs/enterprise-import-debug.log"
    "/opt/cordys/logs/cordys-crm/error.log"
    "backend/crm/logs/error.log"
    "logs/spring.log"
)

FOUND_LOG=false
for LOG_FILE in "${LOG_FILES[@]}"; do
    if [ -f "$LOG_FILE" ]; then
        FOUND_LOG=true
        echo -e "${GREEN}✓ 找到日志文件: $LOG_FILE${NC}"
        echo ""
        
        echo -e "${BLUE}=== 最近的完整异常堆栈（包含 Caused by）===${NC}"
        # 查找最近的异常，包括完整的 Caused by 链
        grep -B 5 -A 50 "Exception\|Error" "$LOG_FILE" | tail -100 || echo "未找到异常"
        echo ""
        
        echo -e "${BLUE}=== 最近的 SQL 执行日志 ===${NC}"
        grep -A 5 "### SQL:" "$LOG_FILE" | tail -30 || echo "未找到 SQL 日志"
        echo ""
        
        echo -e "${BLUE}=== 最近的 MyBatis 参数 ===${NC}"
        grep "### Parameters:" "$LOG_FILE" | tail -10 || echo "未找到参数日志"
        echo ""
        
        echo -e "${BLUE}=== Mapper 加载状态 ===${NC}"
        grep -i "hasStatement\|insertWithDateConversion\|ExtEnterpriseProfileMapper" "$LOG_FILE" | tail -20 || echo "未找到 Mapper 相关日志"
        echo ""
        
        break
    fi
done

if [ "$FOUND_LOG" = false ]; then
    echo -e "${RED}✗ 未找到任何日志文件${NC}"
    echo "请先运行: ./scripts/debug_enterprise_import.sh"
    echo ""
fi

# 2. 检查 Mapper XML 是否存在
echo -e "${YELLOW}[2/6] 检查 Mapper XML 文件...${NC}"
echo ""

MAPPER_XML="backend/crm/target/classes/cn/cordys/crm/integration/mapper/ExtEnterpriseProfileMapper.xml"
if [ -f "$MAPPER_XML" ]; then
    echo -e "${GREEN}✓ ExtEnterpriseProfileMapper.xml 存在${NC}"
    
    # 检查 XML 内容是否包含 insertWithDateConversion
    if grep -q "insertWithDateConversion" "$MAPPER_XML"; then
        echo -e "${GREEN}✓ insertWithDateConversion 方法已定义${NC}"
    else
        echo -e "${RED}✗ insertWithDateConversion 方法未找到！${NC}"
        echo "需要检查 XML 文件内容"
    fi
    
    # 检查 jdbcType=DATE 是否存在
    if grep -q "jdbcType=DATE" "$MAPPER_XML"; then
        echo -e "${GREEN}✓ jdbcType=DATE 已配置${NC}"
    else
        echo -e "${RED}✗ jdbcType=DATE 未配置！${NC}"
    fi
else
    echo -e "${RED}✗ ExtEnterpriseProfileMapper.xml 不存在！${NC}"
    echo "需要重新编译: cd backend/crm && mvn clean compile -DskipTests"
fi
echo ""

# 3. 检查数据库连接和约束
echo -e "${YELLOW}[3/6] 检查数据库连接和约束...${NC}"
echo ""

if command -v mysql &> /dev/null; then
    if mysql -u root -p123456 -e "SELECT 1" cordys_crm &> /dev/null 2>&1; then
        echo -e "${GREEN}✓ 数据库连接正常${NC}"
        
        # 检查重复的 credit_code
        echo ""
        echo -e "${BLUE}=== 检查重复的信用代码 ===${NC}"
        DUPLICATES=$(mysql -u root -p123456 cordys_crm -N -e "
            SELECT credit_code, COUNT(*) as cnt 
            FROM enterprise_profile 
            GROUP BY credit_code 
            HAVING cnt > 1 
            LIMIT 5;" 2>/dev/null || echo "")
        
        if [ -n "$DUPLICATES" ]; then
            echo -e "${RED}✗ 发现重复的信用代码：${NC}"
            echo "$DUPLICATES"
            echo ""
            echo "建议：添加唯一索引防止重复"
            echo "ALTER TABLE enterprise_profile ADD UNIQUE INDEX uk_credit_code_org (credit_code, organization_id);"
        else
            echo -e "${GREEN}✓ 无重复信用代码${NC}"
        fi
        
        # 检查外键约束
        echo ""
        echo -e "${BLUE}=== 检查外键约束 ===${NC}"
        ORPHAN_RECORDS=$(mysql -u root -p123456 cordys_crm -N -e "
            SELECT COUNT(*) 
            FROM enterprise_profile ep 
            LEFT JOIN customer c ON ep.customer_id = c.id 
            WHERE c.id IS NULL;" 2>/dev/null || echo "0")
        
        if [ "$ORPHAN_RECORDS" -gt 0 ]; then
            echo -e "${RED}✗ 发现 $ORPHAN_RECORDS 条孤立记录（customer_id 不存在）${NC}"
        else
            echo -e "${GREEN}✓ 外键约束正常${NC}"
        fi
        
        # 检查字段长度
        echo ""
        echo -e "${BLUE}=== 检查字段定义 ===${NC}"
        mysql -u root -p123456 cordys_crm -e "
            SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH 
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_SCHEMA='cordys_crm' 
              AND TABLE_NAME='enterprise_profile' 
              AND COLUMN_NAME IN ('shareholders', 'executives', 'risks');" 2>/dev/null || echo "查询失败"
        
    else
        echo -e "${RED}✗ 数据库连接失败${NC}"
        echo "请检查数据库是否启动，用户名密码是否正确"
    fi
else
    echo -e "${YELLOW}⚠ mysql 命令不可用，跳过数据库检查${NC}"
fi
echo ""

# 4. 检查后端进程
echo -e "${YELLOW}[4/6] 检查后端进程...${NC}"
echo ""

if pgrep -f "spring-boot:run" > /dev/null || pgrep -f "cordys-crm" > /dev/null; then
    echo -e "${GREEN}✓ 后端进程正在运行${NC}"
    echo ""
    echo "进程信息:"
    ps aux | grep -E "spring-boot:run|cordys-crm" | grep -v grep
else
    echo -e "${RED}✗ 后端进程未运行${NC}"
    echo "请先运行: ./scripts/debug_enterprise_import.sh"
fi
echo ""

# 5. 检查最近的导入记录
echo -e "${YELLOW}[5/6] 检查最近的导入记录...${NC}"
echo ""

if command -v mysql &> /dev/null; then
    if mysql -u root -p123456 -e "SELECT 1" cordys_crm &> /dev/null 2>&1; then
        echo -e "${BLUE}=== 最近 10 条导入记录 ===${NC}"
        mysql -u root -p123456 cordys_crm -e "
            SELECT 
                id, 
                company_name, 
                credit_code, 
                reg_date,
                FROM_UNIXTIME(create_time/1000) as created_at
            FROM enterprise_profile 
            ORDER BY create_time DESC 
            LIMIT 10;" 2>/dev/null || echo "查询失败"
    fi
fi
echo ""

# 6. 生成诊断报告
echo -e "${YELLOW}[6/6] 生成诊断报告...${NC}"
echo ""

REPORT_FILE="logs/diagnostic_report_$(date +%Y%m%d_%H%M%S).txt"
mkdir -p logs

{
    echo "========================================="
    echo "企业导入诊断报告"
    echo "生成时间: $(date)"
    echo "========================================="
    echo ""
    
    echo "## 1. 系统信息"
    echo "Java 版本: $(java -version 2>&1 | head -1)"
    echo "Maven 版本: $(mvn -version 2>&1 | head -1)"
    echo ""
    
    echo "## 2. 后端进程状态"
    if pgrep -f "spring-boot:run" > /dev/null || pgrep -f "cordys-crm" > /dev/null; then
        echo "状态: 运行中"
        ps aux | grep -E "spring-boot:run|cordys-crm" | grep -v grep
    else
        echo "状态: 未运行"
    fi
    echo ""
    
    echo "## 3. Mapper XML 状态"
    if [ -f "$MAPPER_XML" ]; then
        echo "文件存在: 是"
        echo "包含 insertWithDateConversion: $(grep -q 'insertWithDateConversion' "$MAPPER_XML" && echo '是' || echo '否')"
        echo "包含 jdbcType=DATE: $(grep -q 'jdbcType=DATE' "$MAPPER_XML" && echo '是' || echo '否')"
    else
        echo "文件存在: 否"
    fi
    echo ""
    
    echo "## 4. 最近的错误日志"
    for LOG_FILE in "${LOG_FILES[@]}"; do
        if [ -f "$LOG_FILE" ]; then
            echo "=== $LOG_FILE ==="
            tail -100 "$LOG_FILE" | grep -A 30 "Exception\|Error" || echo "无错误"
            echo ""
        fi
    done
    
} > "$REPORT_FILE"

echo -e "${GREEN}✓ 诊断报告已生成: $REPORT_FILE${NC}"
echo ""

echo ""
echo "========================================="
echo "诊断完成"
echo "========================================="
echo ""
echo -e "${YELLOW}下一步：${NC}"
echo "1. 如果看到 'Caused by' 错误，请将完整错误信息发给我"
echo "2. 如果没有看到错误，请运行测试脚本："
echo "   ./scripts/test_enterprise_import_single.sh"
echo "3. 然后再次运行本诊断脚本查看新的错误"

