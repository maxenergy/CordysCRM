#!/bin/bash

# 企业导入问题一键修复脚本
# 自动执行诊断、修复和验证

set -e

echo "========================================="
echo "企业导入问题一键修复"
echo "========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 步骤 1：诊断
echo -e "${YELLOW}[步骤 1/5] 运行诊断...${NC}"
echo ""

./scripts/diagnose_import_error.sh

echo ""
read -p "是否继续修复？(y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "已取消"
    exit 0
fi

# 步骤 2：停止后端
echo -e "${YELLOW}[步骤 2/5] 停止后端服务...${NC}"
echo ""

if pgrep -f "spring-boot:run" > /dev/null; then
    echo "正在停止后端进程..."
    pkill -f "spring-boot:run" || true
    sleep 2
    echo -e "${GREEN}✓ 后端已停止${NC}"
else
    echo "后端未运行，跳过"
fi
echo ""

# 步骤 3：重新编译
echo -e "${YELLOW}[步骤 3/5] 重新编译后端...${NC}"
echo ""

echo "执行: mvn clean compile -DskipTests -pl backend/crm"
mvn clean compile -DskipTests -pl backend/crm

# 验证 Mapper XML
MAPPER_XML="backend/crm/target/classes/cn/cordys/crm/integration/mapper/ExtEnterpriseProfileMapper.xml"
if [ -f "$MAPPER_XML" ]; then
    echo -e "${GREEN}✓ Mapper XML 已生成${NC}"
    
    if grep -q "insertWithDateConversion" "$MAPPER_XML"; then
        echo -e "${GREEN}✓ insertWithDateConversion 方法存在${NC}"
    else
        echo -e "${RED}✗ insertWithDateConversion 方法未找到！${NC}"
        exit 1
    fi
    
    if grep -q "jdbcType=DATE" "$MAPPER_XML"; then
        echo -e "${GREEN}✓ jdbcType=DATE 已配置${NC}"
    else
        echo -e "${RED}✗ jdbcType=DATE 未配置！${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Mapper XML 未生成！${NC}"
    exit 1
fi
echo ""

# 步骤 4：修复数据库约束
echo -e "${YELLOW}[步骤 4/5] 修复数据库约束...${NC}"
echo ""

if command -v mysql &> /dev/null; then
    echo "检查数据库约束..."
    
    # 检查是否已有唯一索引
    INDEX_EXISTS=$(mysql -u root -p123456 cordys_crm -N -e "
        SELECT COUNT(*) 
        FROM INFORMATION_SCHEMA.STATISTICS 
        WHERE TABLE_SCHEMA='cordys_crm' 
          AND TABLE_NAME='enterprise_profile' 
          AND INDEX_NAME='uk_credit_code_org';" 2>/dev/null || echo "0")
    
    if [ "$INDEX_EXISTS" -eq 0 ]; then
        echo "添加唯一索引..."
        mysql -u root -p123456 cordys_crm -e "
            ALTER TABLE enterprise_profile 
            ADD UNIQUE INDEX uk_credit_code_org (credit_code, organization_id);" 2>/dev/null || {
            echo -e "${YELLOW}⚠ 添加唯一索引失败（可能已存在或有重复数据）${NC}"
        }
    else
        echo -e "${GREEN}✓ 唯一索引已存在${NC}"
    fi
    
    # 检查字段类型
    echo "检查字段类型..."
    FIELD_TYPE=$(mysql -u root -p123456 cordys_crm -N -e "
        SELECT DATA_TYPE 
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_SCHEMA='cordys_crm' 
          AND TABLE_NAME='enterprise_profile' 
          AND COLUMN_NAME='shareholders';" 2>/dev/null || echo "")
    
    if [ "$FIELD_TYPE" = "varchar" ]; then
        echo "将 JSON 字段改为 TEXT..."
        mysql -u root -p123456 cordys_crm -e "
            ALTER TABLE enterprise_profile 
            MODIFY COLUMN shareholders TEXT,
            MODIFY COLUMN executives TEXT,
            MODIFY COLUMN risks TEXT;" 2>/dev/null || {
            echo -e "${YELLOW}⚠ 修改字段类型失败${NC}"
        }
    else
        echo -e "${GREEN}✓ 字段类型正确${NC}"
    fi
else
    echo -e "${YELLOW}⚠ mysql 命令不可用，跳过数据库修复${NC}"
fi
echo ""

# 步骤 5：启动后端
echo -e "${YELLOW}[步骤 5/5] 启动后端服务...${NC}"
echo ""

echo "启动后端服务（后台运行）..."
cd backend/app
nohup mvn spring-boot:run > ../../logs/backend.log 2>&1 &
BACKEND_PID=$!
cd ../..

echo "后端进程 PID: $BACKEND_PID"

# 等待后端启动
echo "等待后端启动（最多 60 秒）..."
for i in {1..60}; do
    if curl -s http://localhost:8080/actuator/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 后端已启动${NC}"
        break
    fi
    if [ $i -eq 60 ]; then
        echo -e "${RED}✗ 后端启动超时${NC}"
        echo "查看日志: tail -f logs/backend.log"
        exit 1
    fi
    sleep 1
    echo -n "."
done
echo ""

# 验证
echo ""
echo "========================================="
echo "修复完成，开始验证"
echo "========================================="
echo ""

# 运行单条导入测试
echo -e "${BLUE}运行单条导入测试...${NC}"
./scripts/test_enterprise_import_single.sh

echo ""
echo "========================================="
echo "修复和验证完成"
echo "========================================="
echo ""
echo -e "${GREEN}✓ 修复步骤已完成${NC}"
echo ""
echo "下一步："
echo "1. 检查测试结果是否成功"
echo "2. 在 Flutter 中测试批量导入"
echo "3. 查看后端日志: tail -f logs/enterprise-import-debug.log"
echo ""
