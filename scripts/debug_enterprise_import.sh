#!/bin/bash

# 企业批量导入调试脚本
# 用途：启动后端服务并启用详细的 SQL 日志，帮助定位批量导入问题

set -e

echo "========================================="
echo "企业批量导入调试脚本"
echo "========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. 停止现有后端服务
echo -e "${YELLOW}[1/5] 停止现有后端服务...${NC}"
pkill -f "spring-boot:run" || true
pkill -f "cordys-crm" || true
sleep 2

# 2. 清理并重新编译
echo -e "${YELLOW}[2/5] 清理并重新编译后端代码...${NC}"
mvn clean compile -DskipTests -q -pl backend/crm
echo -e "${GREEN}✓ 编译完成${NC}"

# 3. 验证 Mapper XML 是否存在
echo -e "${YELLOW}[3/5] 验证 Mapper XML 文件...${NC}"
if [ -f "backend/crm/target/classes/cn/cordys/crm/integration/mapper/ExtEnterpriseProfileMapper.xml" ]; then
    echo -e "${GREEN}✓ ExtEnterpriseProfileMapper.xml 存在${NC}"
else
    echo -e "${RED}✗ ExtEnterpriseProfileMapper.xml 不存在！${NC}"
    exit 1
fi

# 4. 启动后端服务（带详细日志）
echo -e "${YELLOW}[4/5] 启动后端服务（启用 SQL 详细日志）...${NC}"
echo ""
echo -e "${GREEN}日志级别配置：${NC}"
echo "  - org.mybatis: DEBUG"
echo "  - cn.cordys.crm.integration.mapper: DEBUG"
echo "  - org.springframework.jdbc: DEBUG"
echo ""
echo -e "${YELLOW}提示：请在另一个终端运行测试脚本${NC}"
echo ""

# 启动服务（从项目根目录运行）
cd backend/app
mvn spring-boot:run \
  -Dspring-boot.run.jvmArguments="-Dlogging.level.org.mybatis=DEBUG -Dlogging.level.cn.cordys.crm.integration.mapper=DEBUG -Dlogging.level.org.springframework.jdbc=DEBUG" \
  2>&1 | tee ../../logs/enterprise-import-debug.log

