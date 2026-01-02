#!/bin/bash

# 增强版企业导入调试脚本
# 用于捕获完整的错误堆栈和 SQL 日志

set -e

echo "========================================="
echo "企业导入增强调试脚本"
echo "========================================="

# 1. 停止现有后端服务
echo ""
echo "步骤 1: 停止现有后端服务..."
pkill -f "cordys-crm" || echo "没有运行中的后端服务"
sleep 2

# 2. 清理旧日志
echo ""
echo "步骤 2: 清理旧日志..."
mkdir -p logs
rm -f logs/enterprise-import-enhanced.log
rm -f logs/enterprise-import-sql.log

# 3. 检查 Mapper XML 文件
echo ""
echo "步骤 3: 检查 Mapper XML 文件..."
MAPPER_XML="backend/crm/src/main/resources/cn/cordys/crm/integration/mapper/ExtEnterpriseProfileMapper.xml"
if [ ! -f "$MAPPER_XML" ]; then
    echo "❌ 错误: Mapper XML 文件不存在: $MAPPER_XML"
    exit 1
fi

echo "✓ Mapper XML 文件存在"
echo "  检查 insertWithDateConversion 方法..."
if grep -q "insertWithDateConversion" "$MAPPER_XML"; then
    echo "  ✓ 找到 insertWithDateConversion 方法"
else
    echo "  ❌ 未找到 insertWithDateConversion 方法"
    exit 1
fi

# 4. 重新编译（确保 Mapper XML 被复制到 target）
echo ""
echo "步骤 4: 重新编译项目..."
cd backend
mvn clean compile -DskipTests -q
if [ $? -ne 0 ]; then
    echo "❌ 编译失败"
    exit 1
fi
cd ..

# 5. 验证 Mapper XML 在 classpath 中
echo ""
echo "步骤 5: 验证 Mapper XML 在 classpath 中..."
TARGET_MAPPER="backend/crm/target/classes/cn/cordys/crm/integration/mapper/ExtEnterpriseProfileMapper.xml"
if [ ! -f "$TARGET_MAPPER" ]; then
    echo "❌ 错误: Mapper XML 未复制到 target: $TARGET_MAPPER"
    exit 1
fi
echo "✓ Mapper XML 已复制到 target"

# 6. 创建增强的 logback 配置
echo ""
echo "步骤 6: 创建增强的日志配置..."
cat > /tmp/logback-debug.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
            <pattern>%d{yyyy-MM-dd HH:mm:ss.SSS} %-5level %logger{36} - %msg%n</pattern>
        </encoder>
    </appender>
    
    <appender name="FILE" class="ch.qos.logback.core.FileAppender">
        <file>logs/enterprise-import-enhanced.log</file>
        <encoder>
            <pattern>%d{yyyy-MM-dd HH:mm:ss.SSS} %-5level %logger{36} - %msg%n</pattern>
        </encoder>
    </appender>
    
    <appender name="SQL_FILE" class="ch.qos.logback.core.FileAppender">
        <file>logs/enterprise-import-sql.log</file>
        <encoder>
            <pattern>%d{yyyy-MM-dd HH:mm:ss.SSS} - %msg%n</pattern>
        </encoder>
    </appender>
    
    <!-- MyBatis SQL 日志 -->
    <logger name="cn.cordys.crm.integration.mapper" level="DEBUG" additivity="false">
        <appender-ref ref="SQL_FILE"/>
        <appender-ref ref="CONSOLE"/>
    </logger>
    
    <!-- 企业服务日志 -->
    <logger name="cn.cordys.crm.integration.service.EnterpriseService" level="DEBUG" additivity="false">
        <appender-ref ref="FILE"/>
        <appender-ref ref="CONSOLE"/>
    </logger>
    
    <!-- 企业控制器日志 -->
    <logger name="cn.cordys.crm.integration.controller.EnterpriseController" level="DEBUG" additivity="false">
        <appender-ref ref="FILE"/>
        <appender-ref ref="CONSOLE"/>
    </logger>
    
    <!-- MyBatis 内部日志 -->
    <logger name="org.apache.ibatis" level="DEBUG" additivity="false">
        <appender-ref ref="SQL_FILE"/>
        <appender-ref ref="CONSOLE"/>
    </logger>
    
    <!-- Spring 事务日志 -->
    <logger name="org.springframework.transaction" level="DEBUG" additivity="false">
        <appender-ref ref="FILE"/>
        <appender-ref ref="CONSOLE"/>
    </logger>
    
    <!-- JDBC 日志 -->
    <logger name="org.springframework.jdbc" level="DEBUG" additivity="false">
        <appender-ref ref="SQL_FILE"/>
        <appender-ref ref="CONSOLE"/>
    </logger>
    
    <root level="INFO">
        <appender-ref ref="CONSOLE"/>
        <appender-ref ref="FILE"/>
    </root>
</configuration>
EOF

# 7. 启动后端服务
echo ""
echo "步骤 7: 启动后端服务（增强调试模式）..."
echo "  日志文件: logs/enterprise-import-enhanced.log"
echo "  SQL 日志: logs/enterprise-import-sql.log"
echo ""

cd backend/app
nohup mvn spring-boot:run \
    -Dspring-boot.run.jvmArguments="-Dlogback.configurationFile=/tmp/logback-debug.xml -Dlogging.level.cn.cordys.crm.integration=DEBUG -Dlogging.level.org.apache.ibatis=DEBUG" \
    > ../../logs/enterprise-import-enhanced.log 2>&1 &

BACKEND_PID=$!
cd ../..

echo "后端服务已启动 (PID: $BACKEND_PID)"
echo ""
echo "等待后端服务启动..."

# 8. 等待后端服务就绪
MAX_WAIT=60
WAIT_COUNT=0
while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    if curl -s http://localhost:8081/actuator/health > /dev/null 2>&1; then
        echo "✓ 后端服务已就绪"
        break
    fi
    echo -n "."
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 2))
done

if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
    echo ""
    echo "❌ 后端服务启动超时"
    echo "查看日志: tail -f logs/enterprise-import-enhanced.log"
    exit 1
fi

echo ""
echo ""
echo "========================================="
echo "调试环境已就绪"
echo "========================================="
echo ""
echo "后端服务: http://localhost:8081"
echo "后端 PID: $BACKEND_PID"
echo ""
echo "日志文件:"
echo "  - 主日志: logs/enterprise-import-enhanced.log"
echo "  - SQL 日志: logs/enterprise-import-sql.log"
echo ""
echo "实时查看日志:"
echo "  tail -f logs/enterprise-import-enhanced.log"
echo "  tail -f logs/enterprise-import-sql.log"
echo ""
echo "运行测试:"
echo "  ./scripts/test_enterprise_import_single.sh"
echo ""
echo "停止后端:"
echo "  kill $BACKEND_PID"
echo ""
echo "========================================="
