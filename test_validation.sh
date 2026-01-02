#!/bin/bash

echo "=== 企业导入验证测试 ==="

# 测试数据 - 模拟企查查返回的数据（creditCode为空）
TEST_DATA='{
  "companyName": "测试企业有限公司",
  "creditCode": "",
  "legalPerson": "",
  "registeredCapital": null,
  "establishmentDate": 1573747200000,
  "address": "",
  "province": "",
  "city": "",
  "industry": "",
  "source": "qcc"
}'

echo "测试数据: $TEST_DATA"

# 直接测试后端API
RESPONSE=$(curl -s -X POST http://localhost:8081/api/enterprise/import \
  -H "Content-Type: application/json" \
  -d "$TEST_DATA")

echo "响应: $RESPONSE"

if echo "$RESPONSE" | grep -q "success"; then
    echo "✅ 测试成功"
else
    echo "❌ 测试失败"
fi
