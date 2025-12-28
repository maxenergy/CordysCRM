#!/bin/bash

# Task 16: Checkpoint E - 同步流程验证测试执行脚本
# 
# 此脚本运行 Task 16 的所有自动化集成测试

set -e

echo "=========================================="
echo "Task 16: Checkpoint E - 同步流程验证测试"
echo "=========================================="
echo ""

# 切换到 Flutter 项目目录
cd "$(dirname "$0")/.."

echo "📦 安装依赖..."
flutter pub get

echo ""
echo "🔨 生成 Mock 文件..."
dart run build_runner build --delete-conflicting-outputs

echo ""
echo "=========================================="
echo "运行集成测试"
echo "=========================================="

# 测试计数器
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 运行 Test 16.1: API Client 不可用场景测试
echo ""
echo "📋 Test 16.1: API Client 不可用场景测试"
echo "------------------------------------------"
if flutter test test/integration/sync_offline_test.dart; then
    echo "✅ Test 16.1: PASSED"
    ((PASSED_TESTS++))
else
    echo "❌ Test 16.1: FAILED"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# 运行 Test 16.2: 错误分类和重试测试
echo ""
echo "📋 Test 16.2: 错误分类和重试测试"
echo "------------------------------------------"
if flutter test test/integration/sync_error_classification_test.dart; then
    echo "✅ Test 16.2: PASSED"
    ((PASSED_TESTS++))
else
    echo "❌ Test 16.2: FAILED"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# 运行 Test 16.3: 重试次数限制测试
echo ""
echo "📋 Test 16.3: 重试次数限制测试"
echo "------------------------------------------"
if flutter test test/integration/sync_retry_limit_test.dart; then
    echo "✅ Test 16.3: PASSED"
    ((PASSED_TESTS++))
else
    echo "❌ Test 16.3: FAILED"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# 输出测试结果摘要
echo ""
echo "=========================================="
echo "测试结果摘要"
echo "=========================================="
echo "总测试数: $TOTAL_TESTS"
echo "通过: $PASSED_TESTS"
echo "失败: $FAILED_TESTS"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo "🎉 所有自动化测试通过！"
    echo ""
    echo "下一步："
    echo "1. 执行 Test 16.4 手动测试（应用崩溃模拟）"
    echo "2. 参考 TASK_16_CHECKPOINT_E_TEST_PLAN.md 中的手动测试步骤"
    echo ""
    exit 0
else
    echo "⚠️  有 $FAILED_TESTS 个测试失败，请检查日志"
    echo ""
    exit 1
fi
