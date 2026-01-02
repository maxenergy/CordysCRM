#!/bin/bash

# 企业导入修复验证脚本

echo "=== 企业导入修复验证测试 ==="

# 1. 获取认证token
echo "1. 获取认证token..."
LOGIN_RESPONSE=$(curl -s -X POST http://192.168.1.226:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "CordysCRM"
  }')

TOKEN=$(echo $LOGIN_RESPONSE | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    echo "❌ 登录失败，无法获取token"
    echo "响应: $LOGIN_RESPONSE"
    exit 1
fi

echo "✅ 登录成功，token: ${TOKEN:0:20}..."

# 2. 测试企业导入API
echo "2. 测试企业导入API..."

# 创建测试数据 - 使用简单的时间戳
TEST_DATA='{
  "companyName": "测试科技有限公司",
  "creditCode": "91110000TEST123456",
  "legalPerson": "张三",
  "registeredCapital": 100.0,
  "establishmentDate": 1573747200000,
  "address": "北京市朝阳区测试街道123号",
  "province": "北京市",
  "city": "北京市",
  "industry": "软件和信息技术服务业",
  "industryCode": "65",
  "staffSize": "50-99人",
  "source": "test"
}'

echo "测试数据: $TEST_DATA"

IMPORT_RESPONSE=$(curl -s -X POST http://192.168.1.226:8081/api/enterprise/import \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-AUTH-TOKEN: $TOKEN" \
  -d "$TEST_DATA")

echo "导入响应: $IMPORT_RESPONSE"

# 3. 检查响应
if echo "$IMPORT_RESPONSE" | grep -q '"success":true'; then
    echo "✅ 企业导入成功！修复生效"
    
    # 提取企业ID
    CUSTOMER_ID=$(echo $IMPORT_RESPONSE | grep -o '"customerId":"[^"]*"' | cut -d'"' -f4)
    echo "企业ID: $CUSTOMER_ID"
    
    # 4. 验证数据库中的数据
    echo "3. 验证导入的数据..."
    QUERY_RESPONSE=$(curl -s -X GET "http://192.168.1.226:8081/api/enterprise/profile/$CUSTOMER_ID" \
      -H "Authorization: Bearer $TOKEN" \
      -H "X-AUTH-TOKEN: $TOKEN")
    
    echo "查询响应: $QUERY_RESPONSE"
    
    if echo "$QUERY_RESPONSE" | grep -q '"regDate":1573747200000'; then
        echo "✅ 时间戳存储正确！"
    else
        echo "⚠️  时间戳存储可能有问题"
    fi
    
else
    echo "❌ 企业导入失败"
    
    # 检查是否还是日期格式错误
    if echo "$IMPORT_RESPONSE" | grep -q "Incorrect date value"; then
        echo "❌ 仍然存在日期格式错误，修复未生效"
    elif echo "$IMPORT_RESPONSE" | grep -q "Data truncation"; then
        echo "❌ 仍然存在数据截断错误"
    else
        echo "❓ 其他错误类型"
    fi
fi

echo "=== 测试完成 ==="
