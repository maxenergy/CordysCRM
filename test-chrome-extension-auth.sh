#!/bin/bash
# Chrome Extension Authentication Test Script

set -e

BASE_URL="http://localhost:8081"

echo "=========================================="
echo "Chrome Extension Authentication Test"
echo "=========================================="

# Step 1: Login to get session ID
echo ""
echo "Step 1: Login..."
LOGIN_RESULT=$(curl -s -X POST "$BASE_URL/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"CordysCRM","platform":"WEB"}')

echo "Login Response:"
echo "$LOGIN_RESULT" | jq .

SESSION_ID=$(echo "$LOGIN_RESULT" | jq -r '.data.sessionId')
echo ""
echo "Session ID: $SESSION_ID"

if [ "$SESSION_ID" == "null" ] || [ -z "$SESSION_ID" ]; then
  echo "ERROR: Failed to get session ID"
  exit 1
fi

# Step 2: Test /anonymous/user/current with Bearer token (public endpoint)
echo ""
echo "=========================================="
echo "Step 2: Test /anonymous/user/current with Bearer token..."
echo "=========================================="

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -H "Authorization: Bearer $SESSION_ID" \
  "$BASE_URL/anonymous/user/current")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "HTTP Status: $HTTP_CODE"
echo "Response Body:"
echo "$BODY" | jq . 2>/dev/null || echo "$BODY"

# Step 3: Test with Session prefix
echo ""
echo "=========================================="
echo "Step 3: Test /anonymous/user/current with Session prefix..."
echo "=========================================="

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -H "Authorization: Session $SESSION_ID" \
  "$BASE_URL/anonymous/user/current")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "HTTP Status: $HTTP_CODE"
echo "Response Body:"
echo "$BODY" | jq . 2>/dev/null || echo "$BODY"

# Step 4: Test without Authorization header (should fail)
echo ""
echo "=========================================="
echo "Step 4: Test without Authorization header (should return 401)..."
echo "=========================================="

RESPONSE=$(curl -s -w "\n%{http_code}" "$BASE_URL/anonymous/user/current")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "HTTP Status: $HTTP_CODE"
echo "Response Body: $BODY"

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Session ID obtained: $SESSION_ID"
