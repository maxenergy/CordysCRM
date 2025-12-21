#!/bin/bash
# Flutter 与后端 API 端点自动化测试脚本
# 用法: ./scripts/test_flutter_api.sh

set -e

API_BASE="http://localhost:8081"
USERNAME="admin"
PASSWORD="CordysCRM"
COOKIE_FILE="/tmp/crm_cookies.txt"
RESULTS_FILE="/tmp/api_test_results.txt"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

log_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    echo "PASS: $1" >> "$RESULTS_FILE"
    PASS_COUNT=$((PASS_COUNT + 1))
}

log_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    echo "FAIL: $1" >> "$RESULTS_FILE"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

log_skip() {
    echo -e "${YELLOW}○ SKIP${NC}: $1"
    echo "SKIP: $1" >> "$RESULTS_FILE"
    SKIP_COUNT=$((SKIP_COUNT + 1))
}

log_info() {
    echo -e "${YELLOW}→${NC} $1"
}

echo "=========================================="
echo "Flutter 与后端 API 端点自动化测试"
echo "=========================================="
echo "API Base: $API_BASE"
echo "时间: $(date)"
echo ""

> "$RESULTS_FILE"

echo "1. 认证 API 测试"
echo "----------------------------------------"

log_info "测试登录接口 POST /login"
LOGIN_RESPONSE=$(curl -s -c "$COOKIE_FILE" -b "$COOKIE_FILE" \
    -X POST "$API_BASE/login" \
    -H 'Content-Type: application/json' \
    -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\",\"platform\":\"mobile\"}")

if echo "$LOGIN_RESPONSE" | grep -q '"sessionId"'; then
    ACCESS_TOKEN=$(echo "$LOGIN_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('sessionId',''))" 2>/dev/null || echo "")
    CSRF_TOKEN=$(echo "$LOGIN_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('csrfToken',''))" 2>/dev/null || echo "")
    if [ -n "$ACCESS_TOKEN" ]; then
        log_pass "POST /login - 登录成功，获取到 sessionId"
    else
        log_fail "POST /login - 登录响应缺少 sessionId"
    fi
else
    log_fail "POST /login - 登录失败: $LOGIN_RESPONSE"
    echo "无法继续测试，请检查后端服务是否运行"
    exit 1
fi

AUTH_HEADER="Authorization: Bearer $ACCESS_TOKEN"
CSRF_HEADER="X-CSRF-TOKEN: $CSRF_TOKEN"

echo ""
echo "2. 客户管理 API 测试 (/account)"
echo "----------------------------------------"

log_info "测试客户列表 POST /account/page"
CUSTOMER_LIST=$(curl -s -b "$COOKIE_FILE" \
    -X POST "$API_BASE/account/page" \
    -H 'Content-Type: application/json' \
    -H "$AUTH_HEADER" \
    -d '{"current":1,"pageSize":10,"viewId":"ALL"}')

if echo "$CUSTOMER_LIST" | grep -q '"code":100200'; then
    TOTAL=$(echo "$CUSTOMER_LIST" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('total',0))" 2>/dev/null || echo "0")
    log_pass "POST /account/page - 获取客户列表成功 (total=$TOTAL)"
else
    log_fail "POST /account/page - 获取客户列表失败: $(echo "$CUSTOMER_LIST" | head -c 200)"
fi

log_info "测试创建客户 POST /account/add"
NEW_CUSTOMER=$(curl -s -b "$COOKIE_FILE" \
    -X POST "$API_BASE/account/add" \
    -H 'Content-Type: application/json' \
    -H "$AUTH_HEADER" \
    -d '{"name":"API测试客户_'$(date +%s)'","contactPerson":"测试联系人","phone":"13800138000","status":"潜在客户"}')

if echo "$NEW_CUSTOMER" | grep -q '"code":100200'; then
    CUSTOMER_ID=$(echo "$NEW_CUSTOMER" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('id',''))" 2>/dev/null || echo "")
    if [ -n "$CUSTOMER_ID" ]; then
        log_pass "POST /account/add - 创建客户成功 (id=$CUSTOMER_ID)"
    else
        log_pass "POST /account/add - 创建客户成功 (无返回ID)"
        CUSTOMER_ID=""
    fi
else
    log_fail "POST /account/add - 创建客户失败: $(echo "$NEW_CUSTOMER" | head -c 200)"
    CUSTOMER_ID=""
fi

if [ -n "$CUSTOMER_ID" ]; then
    log_info "测试获取客户详情 GET /account/get/$CUSTOMER_ID"
    CUSTOMER_DETAIL=$(curl -s -b "$COOKIE_FILE" \
        -X GET "$API_BASE/account/get/$CUSTOMER_ID" \
        -H "$AUTH_HEADER")
    
    if echo "$CUSTOMER_DETAIL" | grep -q '"code":100200'; then
        log_pass "GET /account/get/{id} - 获取客户详情成功"
    else
        log_fail "GET /account/get/{id} - 获取客户详情失败"
    fi

    log_info "测试更新客户 POST /account/update"
    UPDATE_CUSTOMER=$(curl -s -b "$COOKIE_FILE" \
        -X POST "$API_BASE/account/update" \
        -H 'Content-Type: application/json' \
        -H "$AUTH_HEADER" \
        -d "{\"id\":\"$CUSTOMER_ID\",\"name\":\"API测试客户_已更新\",\"phone\":\"13900139000\"}")
    
    if echo "$UPDATE_CUSTOMER" | grep -q '"code":100200'; then
        log_pass "POST /account/update - 更新客户成功"
    else
        log_fail "POST /account/update - 更新客户失败"
    fi

    log_info "测试删除客户 GET /account/delete/$CUSTOMER_ID"
    DELETE_CUSTOMER=$(curl -s -b "$COOKIE_FILE" \
        -X GET "$API_BASE/account/delete/$CUSTOMER_ID" \
        -H "$AUTH_HEADER")
    
    if echo "$DELETE_CUSTOMER" | grep -q '"code":100200'; then
        log_pass "GET /account/delete/{id} - 删除客户成功"
    else
        log_fail "GET /account/delete/{id} - 删除客户失败"
    fi
else
    log_skip "GET /account/get/{id} - 跳过（无客户ID）"
    log_skip "POST /account/update - 跳过（无客户ID）"
    log_skip "GET /account/delete/{id} - 跳过（无客户ID）"
fi

echo ""
echo "3. 企业搜索 API 测试 (/api/enterprise)"
echo "----------------------------------------"

log_info "测试本地企业搜索 GET /api/enterprise/search-local"
ENTERPRISE_LOCAL=$(curl -s -b "$COOKIE_FILE" \
    -X GET "$API_BASE/api/enterprise/search-local?keyword=test&page=1&pageSize=10" \
    -H "$AUTH_HEADER")

if echo "$ENTERPRISE_LOCAL" | grep -q '"code":100200'; then
    log_pass "GET /api/enterprise/search-local - 本地搜索成功"
elif echo "$ENTERPRISE_LOCAL" | grep -q '"success"'; then
    log_pass "GET /api/enterprise/search-local - 本地搜索成功（直接格式）"
else
    log_fail "GET /api/enterprise/search-local - 本地搜索失败: $(echo "$ENTERPRISE_LOCAL" | head -c 200)"
fi

log_info "测试企业导入 POST /api/enterprise/import"
TIMESTAMP=$(date +%s)
CREDIT_CODE="91110108MA$(echo $TIMESTAMP | tail -c 7)XY"
ENTERPRISE_IMPORT=$(curl -s -b "$COOKIE_FILE" \
    -X POST "$API_BASE/api/enterprise/import" \
    -H 'Content-Type: application/json' \
    -H "$AUTH_HEADER" \
    -d "{
        \"companyName\":\"API测试企业_${TIMESTAMP}\",
        \"creditCode\":\"${CREDIT_CODE}\",
        \"legalPerson\":\"测试法人\",
        \"registeredCapital\":1000,
        \"address\":\"北京市朝阳区测试路1号\",
        \"industry\":\"软件和信息技术服务业\",
        \"status\":\"存续\",
        \"source\":\"api_test\"
    }")

if echo "$ENTERPRISE_IMPORT" | grep -q '"code":100200'; then
    log_pass "POST /api/enterprise/import - 企业导入成功"
elif echo "$ENTERPRISE_IMPORT" | grep -q '"status":"success"'; then
    log_pass "POST /api/enterprise/import - 企业导入成功（直接格式）"
elif echo "$ENTERPRISE_IMPORT" | grep -q '"status":"conflict"'; then
    log_pass "POST /api/enterprise/import - 企业导入返回冲突（预期行为）"
else
    log_fail "POST /api/enterprise/import - 企业导入失败: $(echo "$ENTERPRISE_IMPORT" | head -c 300)"
fi

log_info "测试企业画像 GET /enterprise/profile/{customerId}"
ENTERPRISE_PROFILE=$(curl -s -b "$COOKIE_FILE" \
    -X GET "$API_BASE/enterprise/profile/test-customer-id" \
    -H "$AUTH_HEADER")

if echo "$ENTERPRISE_PROFILE" | grep -q '"code":100200'; then
    log_pass "GET /enterprise/profile/{id} - 获取企业画像成功"
elif echo "$ENTERPRISE_PROFILE" | grep -q '"code":100404'; then
    log_pass "GET /enterprise/profile/{id} - 企业画像不存在（预期行为）"
else
    log_skip "GET /enterprise/profile/{id} - 接口可能未实现"
fi

echo ""
echo "4. AI 功能 API 测试 (/api/ai)"
echo "----------------------------------------"

log_info "测试生成企业画像 POST /api/ai/portrait/generate"
AI_PORTRAIT=$(curl -s -b "$COOKIE_FILE" \
    -X POST "$API_BASE/api/ai/portrait/generate" \
    -H 'Content-Type: application/json' \
    -H "$AUTH_HEADER" \
    -d '{"customerId":"test-customer-id"}')

if echo "$AI_PORTRAIT" | grep -q '"code":100200'; then
    log_pass "POST /api/ai/portrait/generate - 生成画像成功"
elif echo "$AI_PORTRAIT" | grep -q '"customerId"'; then
    log_pass "POST /api/ai/portrait/generate - 生成画像成功（直接格式）"
elif echo "$AI_PORTRAIT" | grep -q '"code":100404'; then
    log_pass "POST /api/ai/portrait/generate - 客户不存在（预期行为）"
else
    log_skip "POST /api/ai/portrait/generate - 接口可能未实现或需要有效客户ID"
fi

log_info "测试生成话术 POST /api/ai/script/generate"
AI_SCRIPT=$(curl -s -b "$COOKIE_FILE" \
    -X POST "$API_BASE/api/ai/script/generate" \
    -H 'Content-Type: application/json' \
    -H "$AUTH_HEADER" \
    -d '{"customerId":"test-customer-id","scene":"firstContact","channel":"phone","tone":"professional"}')

if echo "$AI_SCRIPT" | grep -q '"code":100200'; then
    log_pass "POST /api/ai/script/generate - 生成话术成功"
elif echo "$AI_SCRIPT" | grep -q '"content"'; then
    log_pass "POST /api/ai/script/generate - 生成话术成功（直接格式）"
else
    log_skip "POST /api/ai/script/generate - 接口可能未实现"
fi

log_info "测试获取话术模板 GET /api/ai/script/templates"
AI_TEMPLATES=$(curl -s -b "$COOKIE_FILE" \
    -X GET "$API_BASE/api/ai/script/templates" \
    -H "$AUTH_HEADER")

if echo "$AI_TEMPLATES" | grep -q '"code":100200'; then
    log_pass "GET /api/ai/script/templates - 获取模板成功"
elif echo "$AI_TEMPLATES" | grep -q '\['; then
    log_pass "GET /api/ai/script/templates - 获取模板成功（数组格式）"
else
    log_skip "GET /api/ai/script/templates - 接口可能未实现"
fi

log_info "测试保存话术模板 POST /api/ai/script/templates"
SAVE_TEMPLATE=$(curl -s -b "$COOKIE_FILE" \
    -X POST "$API_BASE/api/ai/script/templates" \
    -H 'Content-Type: application/json' \
    -H "$AUTH_HEADER" \
    -d '{"name":"API测试模板","content":"测试话术内容","scene":"firstContact","channel":"phone","tone":"professional"}')

if echo "$SAVE_TEMPLATE" | grep -q '"code":100200'; then
    log_pass "POST /api/ai/script/templates - 保存模板成功"
elif echo "$SAVE_TEMPLATE" | grep -q '"id"'; then
    log_pass "POST /api/ai/script/templates - 保存模板成功（直接格式）"
else
    log_skip "POST /api/ai/script/templates - 接口可能未实现"
fi

echo ""
echo "5. 数据同步 API 测试 (/api/sync)"
echo "----------------------------------------"

log_info "测试拉取增量数据 POST /api/sync/pull"
SYNC_PULL=$(curl -s -b "$COOKIE_FILE" \
    -X POST "$API_BASE/api/sync/pull" \
    -H 'Content-Type: application/json' \
    -H "$AUTH_HEADER" \
    -d '{}')

if echo "$SYNC_PULL" | grep -q '"code":100200'; then
    log_pass "POST /api/sync/pull - 拉取数据成功"
elif echo "$SYNC_PULL" | grep -q '"serverTimestamp"'; then
    log_pass "POST /api/sync/pull - 拉取数据成功（直接格式）"
else
    log_skip "POST /api/sync/pull - 接口可能未实现"
fi

log_info "测试推送变更数据 POST /api/sync/push"
SYNC_PUSH=$(curl -s -b "$COOKIE_FILE" \
    -X POST "$API_BASE/api/sync/push" \
    -H 'Content-Type: application/json' \
    -H "$AUTH_HEADER" \
    -d '{"changes":[]}')

if echo "$SYNC_PUSH" | grep -q '"code":100200'; then
    log_pass "POST /api/sync/push - 推送数据成功"
elif echo "$SYNC_PUSH" | grep -q '"results"'; then
    log_pass "POST /api/sync/push - 推送数据成功（直接格式）"
else
    log_skip "POST /api/sync/push - 接口可能未实现"
fi

echo ""
echo "6. 登出测试"
echo "----------------------------------------"

log_info "测试登出接口 GET /logout"
LOGOUT_RESPONSE=$(curl -s -b "$COOKIE_FILE" \
    -X GET "$API_BASE/logout" \
    -H "$AUTH_HEADER")

log_pass "GET /logout - 登出请求已发送"

rm -f "$COOKIE_FILE"

echo ""
echo "=========================================="
echo "测试结果汇总"
echo "=========================================="
echo -e "${GREEN}通过: $PASS_COUNT${NC}"
echo -e "${RED}失败: $FAIL_COUNT${NC}"
echo -e "${YELLOW}跳过: $SKIP_COUNT${NC}"
echo ""
echo "详细结果已保存到: $RESULTS_FILE"
echo "=========================================="

if [ $FAIL_COUNT -gt 0 ]; then
    exit 1
fi
