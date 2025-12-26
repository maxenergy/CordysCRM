#!/bin/bash
# 运行企业搜索属性测试
# 用法: ./scripts/test_property_tests.sh

set -e

cd mobile/cordyscrm_flutter

echo "=========================================="
echo "运行企业搜索属性测试"
echo "=========================================="

flutter test test/property_tests/enterprise_search_notifier_test.dart

echo ""
echo "=========================================="
echo "属性测试完成"
echo "=========================================="
