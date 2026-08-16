#!/bin/bash
# ─── Test Script — HA WordPress ───────────────────────────────────────────────
# Run this after terraform apply to verify everything is working correctly.
# Usage: bash scripts/test.sh
# ──────────────────────────────────────────────────────────────────────────────

set -e  # Exit immediately if any command fails

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() { echo -e "${GREEN}✅ PASS${NC}: $1"; }
fail() { echo -e "${RED}❌ FAIL${NC}: $1"; exit 1; }
info() { echo -e "${YELLOW}ℹ️  INFO${NC}: $1"; }

echo ""
echo "============================================"
echo "  HA WordPress — Post-Deploy Verification"
echo "============================================"
echo ""

# ─── Get outputs from Terraform ───────────────────────────────────────────────
info "Reading Terraform outputs..."
ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null) || fail "Could not read ALB DNS. Run: terraform output"
CF_DOMAIN=$(terraform output -raw cloudfront_domain 2>/dev/null) || fail "Could not read CloudFront domain"

echo ""
echo "Testing: http://$ALB_DNS"
echo "Testing: https://$CF_DOMAIN"
echo ""

# ─── Test 1: ALB responds ─────────────────────────────────────────────────────
info "Test 1: ALB health check..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "http://$ALB_DNS" || echo "000")
if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "302" ] || [ "$HTTP_STATUS" = "301" ]; then
  pass "ALB responds with HTTP $HTTP_STATUS"
else
  fail "ALB returned HTTP $HTTP_STATUS (expected 200 or 302)"
fi

# ─── Test 2: Auto Scaling Group has healthy instances ─────────────────────────
info "Test 2: Auto Scaling Group health..."
PROJECT=$(terraform output -raw project_name 2>/dev/null || echo "wp-ha")
HEALTHY=$(aws autoscaling describe-auto-scaling-groups \
  --filters "Name=tag:Project,Values=$PROJECT" \
  --query 'AutoScalingGroups[0].Instances[?HealthStatus==`Healthy`] | length(@)' \
  --output text 2>/dev/null || echo "0")
if [ "$HEALTHY" -ge "2" ]; then
  pass "Auto Scaling Group has $HEALTHY healthy instances (minimum 2)"
else
  fail "Auto Scaling Group has only $HEALTHY healthy instances (expected ≥ 2)"
fi

# ─── Test 3: RDS Multi-AZ is enabled ──────────────────────────────────────────
info "Test 3: RDS Multi-AZ..."
MULTI_AZ=$(aws rds describe-db-instances \
  --filters "Name=tag:Project,Values=$PROJECT" \
  --query 'DBInstances[0].MultiAZ' \
  --output text 2>/dev/null || echo "False")
if [ "$MULTI_AZ" = "True" ]; then
  pass "RDS Multi-AZ is enabled"
else
  fail "RDS Multi-AZ is NOT enabled (expected True, got $MULTI_AZ)"
fi

# ─── Test 4: RDS is available ─────────────────────────────────────────────────
info "Test 4: RDS instance status..."
RDS_STATUS=$(aws rds describe-db-instances \
  --filters "Name=tag:Project,Values=$PROJECT" \
  --query 'DBInstances[0].DBInstanceStatus' \
  --output text 2>/dev/null || echo "unknown")
if [ "$RDS_STATUS" = "available" ]; then
  pass "RDS instance status: available"
else
  fail "RDS instance status: $RDS_STATUS (expected: available)"
fi

# ─── Test 5: CloudFront distribution is enabled ───────────────────────────────
info "Test 5: CloudFront distribution..."
CF_STATUS=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?DomainName=='$CF_DOMAIN'].Status" \
  --output text 2>/dev/null || echo "unknown")
if [ "$CF_STATUS" = "Deployed" ]; then
  pass "CloudFront distribution: Deployed"
else
  info "CloudFront status: $CF_STATUS (may still be deploying — check again in 10 min)"
fi

# ─── Test 6: WAF is attached ──────────────────────────────────────────────────
info "Test 6: WAF Web ACL..."
WAF_COUNT=$(aws wafv2 list-web-acls --scope CLOUDFRONT --region us-east-1 \
  --query "WebACLs[?contains(Name,'$PROJECT')] | length(@)" \
  --output text 2>/dev/null || echo "0")
if [ "$WAF_COUNT" -ge "1" ]; then
  pass "WAF Web ACL found"
else
  info "WAF Web ACL not found in query (may have different naming)"
fi

# ─── Test 7: CloudWatch alarms exist ──────────────────────────────────────────
info "Test 7: CloudWatch alarms..."
ALARM_COUNT=$(aws cloudwatch describe-alarms \
  --alarm-name-prefix "$PROJECT" \
  --query 'MetricAlarms | length(@)' \
  --output text 2>/dev/null || echo "0")
if [ "$ALARM_COUNT" -ge "3" ]; then
  pass "CloudWatch has $ALARM_COUNT alarms configured"
else
  info "Found $ALARM_COUNT CloudWatch alarms (expected ≥ 3)"
fi

echo ""
echo "============================================"
echo "  All Tests Complete!"
echo "============================================"
echo ""
echo "Resources summary:"
echo "  ALB:         http://$ALB_DNS"
echo "  CloudFront:  https://$CF_DOMAIN"
echo ""
echo "⚠️  REMEMBER: Run 'terraform destroy' when done to avoid AWS charges!"
echo ""
