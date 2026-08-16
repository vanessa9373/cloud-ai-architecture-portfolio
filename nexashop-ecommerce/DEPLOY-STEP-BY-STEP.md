# Project 4: NexaShop E-Commerce Platform — Deployment Guide

> **Goal:** Deploy a production e-commerce platform for 10M+ users using polyglot persistence (multiple databases, each chosen for its workload).
> **Time to complete:** ~60 minutes (RDS + ElastiCache take longer to provision)
> **AWS Cost estimate:** ~$0.25/hour while running. ALWAYS DESTROY WHEN DONE.

---

## Architecture Diagram

```
Customer Browser
      │
      ▼
┌─────────────────────────────────────────────────┐
│   CloudFront CDN + WAF (OWASP Top 10 rules)     │
│   S3: React Frontend (static files)             │
└─────────┬──────────────────────────────────────┘
          │ API requests only
          ▼
┌─────────────────────────────────────────────────┐
│   API Gateway → Lambda Functions                │
│   POST /auth/login  (Cognito JWT validation)    │
│   GET  /products    (product catalog)           │
│   POST /orders      (place order)               │
│   GET  /cart        (session/cart lookup)       │
└──────┬──────────┬──────────────┬───────────────┘
       │          │              │
       ▼          ▼              ▼
┌──────────┐ ┌──────────┐ ┌──────────────────┐
│ DynamoDB │ │ElastiCache│ │ Aurora PostgreSQL │
│ Catalog  │ │  Redis    │ │ Orders (ACID)    │
│(browse,  │ │(sessions, │ │(transactions,    │
│ listings)│ │  cart)    │ │ order history)   │
└──────────┘ └──────────┘ └────────┬─────────┘
                                    │ on order placed
                                    ▼
                           ┌─────────────────┐
                           │   SQS FIFO      │
                           │ Order Queue     │
                           │      │          │
                           │      ▼          │
                           │ Lambda Processor│
                           │      │          │
                           │      ▼          │
                           │ SES Email       │
                           └─────────────────┘
```

## Why Three Databases? (Polyglot Persistence)

This is the most important concept to explain in interviews:

| Database | Used For | Why This Choice |
|----------|----------|-----------------|
| **DynamoDB** | Product catalog, search | Millions of products, read-heavy, flexible schema, auto-scales |
| **ElastiCache Redis** | Shopping cart, sessions | Sub-millisecond reads, TTL expiry, ephemeral data |
| **Aurora PostgreSQL** | Orders, payments | ACID transactions (partial orders = bad), complex queries, joins |

**Interview answer:** "I used polyglot persistence — choosing the right database for each workload's access pattern. Product browsing needs millisecond reads at scale → DynamoDB. Cart data is ephemeral and needs sub-millisecond access → Redis. Orders need ACID guarantees (you can't have a partial order write) → Aurora PostgreSQL."

---

## Prerequisites

```
[ ] AWS CLI configured
[ ] Terraform >= 1.6 installed
[ ] Python 3.12 installed
[ ] Node.js 18+ (for building the React frontend)
[ ] Git installed
```

---

## Step 1: Project Structure Overview

```
nexashop-ecommerce/
├── src/
│   ├── products/handler.py      ← DynamoDB product catalog CRUD
│   ├── orders/handler.py        ← Aurora order processing + SQS
│   └── notifications/handler.py ← SES email confirmation
├── terraform/
│   ├── main.tf                  ← Root — calls all modules
│   ├── provider.tf              ← AWS provider config
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
│       ├── vpc/                 ← VPC + subnets
│       ├── cdn/                 ← CloudFront + S3 + WAF
│       ├── cognito/             ← User authentication
│       ├── rds/                 ← Aurora PostgreSQL Multi-AZ
│       ├── elasticache/         ← Redis for sessions/car
│       └── sqs/                 ← Order processing queue
├── bootstrap/main.tf
└── .github/workflows/deploy.yml
```

---

## Step 2: Bootstrap (One-Time)

```bash
cd nexashop-ecommerce/bootstrap
terraform ini
terraform apply
# Type "yes"
cd ..
```

---

## Step 3: Set Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
project_name  = "nexashop"
environment   = "dev"
aws_region    = "us-east-1"
alert_email   = "your-email@gmail.com"
db_password   = "ChangeMe123!"   # At least 8 chars, letters + numbers
```

---

## Step 4: Deploy Infrastructure

```bash
terraform ini
terraform plan    # Should show ~45-55 resources
terraform apply   # Takes 20-30 minutes (Aurora is slow to provision)
# Type "yes"
```

**Expected outputs:**
```
api_url           = "https://abc123.execute-api.us-east-1.amazonaws.com"
cloudfront_url    = "https://d1234.cloudfront.net"
aurora_endpoint   = "nexashop-dev.cluster-abc.us-east-1.rds.amazonaws.com"
redis_endpoint    = "nexashop-dev.abc.cache.amazonaws.com:6379"
cognito_pool_id   = "us-east-1_ABC123"
```

---

## Step 5: Test the API

```bash
API_URL=$(terraform output -raw api_url)

# Test: Browse products
curl "$API_URL/products"

# Test: Place an order (requires auth token — get from Cognito first)
# 1. Sign up a test user
aws cognito-idp sign-up
  --client-id $(terraform output -raw cognito_client_id)
  --username test@example.com
  --password "TestPass123!"

# 2. Confirm the user
aws cognito-idp admin-confirm-sign-up
  --user-pool-id $(terraform output -raw cognito_pool_id)
  --username test@example.com

# 3. Get JWT token
TOKEN=$(aws cognito-idp initiate-auth
  --auth-flow USER_PASSWORD_AUTH
  --client-id $(terraform output -raw cognito_client_id)
  --auth-parameters USERNAME=test@example.com,PASSWORD="TestPass123!"
  --query 'AuthenticationResult.IdToken'
  --output text)

# 4. Place an order (authenticated)
curl -X POST "$API_URL/orders"
  -H "Authorization: Bearer $TOKEN"
  -H "Content-Type: application/json"
  -d '{"items": [{"product_id": "prod-001", "quantity": 2, "price": 29.99}]}'
```

---

## Step 6: Understand the Order Processing Flow

When a customer places an order:

1. **Lambda (orders/handler.py)** writes order to Aurora with ACID transaction
2. **Lambda** sends a message to SQS FIFO queue: `{"order_id": "...", "customer_email": "..."}`
3. **SQS** delivers message to **Lambda (notifications/handler.py)**
4. **Notifications Lambda** sends confirmation email via SES
5. If SES fails → SQS retries up to 3 times → then sends to Dead Letter Queue
6. **CloudWatch alarm** fires if DLQ receives any message → you get an email

This is called **decoupled architecture** — the order is saved instantly (step 1), and the email happens asynchronously (steps 2-4). If the email fails, the order is NOT lost.

---

## Step 7: Check Cost Savings

```bash
# Run the cost comparison scrip
bash scripts/cost-comparison.sh
```

Shows: Cloud (~$297/month) vs On-Prem equivalent (~$1,800/month) = 83% savings.

---

## Step 8: DESTROY When Done

```bash
terraform destroy
# Type "yes"
# Takes ~15 minutes
```

---

## Common Issues

| Issue | Fix |
|-------|-----|
| `Aurora timeout during creation` | Normal — Aurora takes 15-20 min. Just wait. |
| `Redis connection refused` | Redis is in private subnet — Lambda must be in same VPC |
| `Cognito unauthorized` | Use the correct cognito_client_id from `terraform output` |
| `SES sandbox mode — email not delivered` | Verify your email in SES console first |

---

## What to Say in an Interview

> "NexaShop is a cloud-native e-commerce platform designed for 10 million plus users. I used polyglot persistence: DynamoDB for product catalog with a category GSI for browse queries, Aurora PostgreSQL Multi-AZ for orders because they need ACID transactions — a partial order write would be a serious bug — and ElastiCache Redis for shopping cart sessions with sub-millisecond read latency and TTL-based expiry. Orders are decoupled from notifications via SQS, so a failed email never blocks order confirmation. The entire platform costs approximately $297 per month versus an on-premise equivalent of $1,800 per month — an 83% cost reduction."
