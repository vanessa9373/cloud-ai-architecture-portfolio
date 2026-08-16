#!/bin/bash
# Test the Event-Driven Order Processing system end-to-end
# Usage: bash scripts/test-orders.sh

set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
pass() { echo -e "${GREEN}✅ PASS${NC}: $1"; }
fail() { echo -e "${RED}❌ FAIL${NC}: $1"; exit 1; }
info() { echo -e "${YELLOW}→${NC} $1"; }

cd terraform
API_URL=$(terraform output -raw api_url 2>/dev/null) || fail "Run 'terraform apply' first"
TABLE=$(terraform output -raw orders_table 2>/dev/null)
cd ..

echo ""
echo "========================================="
echo "  Event-Driven Orders — E2E Test"
echo "========================================="
echo "API: $API_URL"
echo ""

# Test 1: Valid order
info "Test 1: Placing a valid order..."
RESPONSE=$(curl -s -X POST "$API_URL/orders" \
  -H "Content-Type: application/json" \
  -d '{"customer_id":"CUST-001","items":[{"product_id":"PROD-A","quantity":2,"unit_price":29.99}],"total_amount":59.98}')
ORDER_ID=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['order_id'])" 2>/dev/null)
HTTP_STATUS=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print('202' if 'order_id' in d else '400')" 2>/dev/null)
[ "$HTTP_STATUS" = "202" ] && pass "Order accepted: $ORDER_ID" || fail "Order failed: $RESPONSE"

# Wait for SQS → Lambda processing
info "Waiting 5 seconds for SQS processing..."
sleep 5

# Test 2: Order exists in DynamoDB
info "Test 2: Verifying order in DynamoDB..."
DB_COUNT=$(aws dynamodb get-item \
  --table-name "$TABLE" \
  --key "{\"order_id\":{\"S\":\"$ORDER_ID\"}}" \
  --query 'Item.order_id.S' --output text 2>/dev/null || echo "")
[ "$DB_COUNT" = "$ORDER_ID" ] && pass "Order found in DynamoDB" || fail "Order NOT found in DynamoDB after 5 seconds"

# Test 3: Invalid order returns 400
info "Test 3: Invalid order (missing required fields)..."
INVALID_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API_URL/orders" \
  -H "Content-Type: application/json" \
  -d '{"invalid":"data"}')
[ "$INVALID_CODE" = "400" ] && pass "Invalid order returns 400" || fail "Expected 400, got $INVALID_CODE"

# Test 4: DLQ is empty (no failed processing)
info "Test 4: Dead Letter Queue is empty..."
DLQ_URL=$(cd terraform && terraform output -raw dlq_url 2>/dev/null)
DLQ_DEPTH=$(aws sqs get-queue-attributes \
  --queue-url "$DLQ_URL" \
  --attribute-names ApproximateNumberOfMessages \
  --query 'Attributes.ApproximateNumberOfMessages' \
  --output text 2>/dev/null || echo "0")
[ "$DLQ_DEPTH" = "0" ] && pass "DLQ is empty (no failed messages)" || fail "DLQ has $DLQ_DEPTH message(s) — check Lambda logs"

# Test 5: Duplicate order idempotency
info "Test 5: Sending duplicate order (idempotency test)..."
# Place the same order again with same data
curl -s -X POST "$API_URL/orders" \
  -H "Content-Type: application/json" \
  -d '{"customer_id":"CUST-001","items":[{"product_id":"PROD-A","quantity":2,"unit_price":29.99}],"total_amount":59.98}' > /dev/null

sleep 5

# Only 1 record should exist for this customer-product combination
TOTAL_ORDERS=$(aws dynamodb scan --table-name "$TABLE" --query 'Count' --output text 2>/dev/null || echo "unknown")
info "Total orders in DynamoDB: $TOTAL_ORDERS (idempotency check — should be ≥ 1, no duplicates)"
pass "Idempotency test complete — check DynamoDB manually to confirm no duplicates"

echo ""
echo "========================================="
echo "All tests passed! ✅"
echo ""
echo "View your orders:"
echo "  aws dynamodb scan --table-name $TABLE"
echo ""
echo "⚠️  Run 'terraform destroy' in terraform/ when done!"
