#!/bin/bash
# Test the live Serverless Task API end-to-end
# Usage: bash scripts/test-api.sh
# Run this AFTER terraform apply

set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
pass() { echo -e "${GREEN}✅ PASS${NC}: $1"; }
fail() { echo -e "${RED}❌ FAIL${NC}: $1"; exit 1; }
info() { echo -e "${YELLOW}→${NC} $1"; }

cd terraform
API_URL=$(terraform output -raw api_url 2>/dev/null) || fail "Run terraform apply first"
cd ..

echo ""
echo "Testing API: $API_URL"
echo "========================================="

# Test 1: Create a task
info "Creating a task..."
RESPONSE=$(curl -s -X POST "$API_URL/tasks" \
  -H "Content-Type: application/json" \
  -d '{"title":"Test Task","description":"Created by test script","priority":"high"}')
TASK_ID=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['task_id'])" 2>/dev/null)
[ -n "$TASK_ID" ] && pass "Task created: $TASK_ID" || fail "Create task failed. Response: $RESPONSE"

# Test 2: Get the task
info "Getting task $TASK_ID..."
STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/tasks/$TASK_ID")
[ "$STATUS_CODE" = "200" ] && pass "GET /tasks/$TASK_ID returned 200" || fail "Expected 200, got $STATUS_CODE"

# Test 3: List all tasks
info "Listing all tasks..."
COUNT=$(curl -s "$API_URL/tasks" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('count',0))" 2>/dev/null)
[ "$COUNT" -ge "1" ] && pass "Task list returned $COUNT task(s)" || fail "Task list empty"

# Test 4: Update task
info "Updating task to 'completed'..."
UPDATE_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH "$API_URL/tasks/$TASK_ID" \
  -H "Content-Type: application/json" -d '{"status":"completed"}')
[ "$UPDATE_CODE" = "200" ] && pass "PATCH returned 200" || fail "Update failed: $UPDATE_CODE"

# Test 5: Delete task
info "Deleting task..."
DELETE_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$API_URL/tasks/$TASK_ID")
[ "$DELETE_CODE" = "200" ] && pass "DELETE returned 200" || fail "Delete failed: $DELETE_CODE"

# Test 6: Confirm deleted
info "Confirming deletion..."
AFTER_DELETE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/tasks/$TASK_ID")
[ "$AFTER_DELETE" = "404" ] && pass "Task confirmed deleted (404)" || fail "Task still exists after delete: $AFTER_DELETE"

echo ""
echo "========================================="
echo "All 6 API tests passed!"
echo ""
echo "⚠️  Run 'terraform destroy' in terraform/ when done to avoid charges"
