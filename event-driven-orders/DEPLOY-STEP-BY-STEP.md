# Project 7: Event-Driven Serverless Order Processing — Deployment Guide

> **Goal:** Build an order intake API → SQS FIFO queue → Lambda processor → DynamoDB with ZERO duplicate orders guaranteed.
> **Time to complete:** ~25 minutes
> **AWS Cost:** Effectively free under AWS free tier for learning volume.

---

## Architecture Diagram

```
Customer places order
        │
        ▼
┌────────────────────────────────────────────────────────────┐
│  API Gateway HTTP API                                       │
│  POST /orders                                              │
│  Rate limit: 10,000 req/sec | Burst: 5,000                │
└────────────────────┬───────────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────────┐
│  Lambda: Validator (Python 3.12, arm64/Graviton2)          │
│  1. Validates required fields (customer_id, items, total)  │
│  2. Generates unique order_id (UUID)                       │
│  3. Sends to SQS FIFO queue                               │
│  4. Returns HTTP 202 Accepted immediately                  │
└────────────────────┬───────────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────────┐
│  SQS FIFO Queue: order-intake.fifo                         │
│  MessageGroupId = customer_id (orders per customer ordered)│
│  MessageDeduplicationId = order_id (5-min dedup window)    │
│  Visibility timeout: 30 seconds                            │
│              │                                             │
│              │ (if fails 3 times)                         │
│              ▼                                             │
│  Dead Letter Queue (DLQ): order-dlq.fifo                  │
│  CloudWatch alarm: DLQ depth > 0 → email alert            │
└────────────────────┬───────────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────────┐
│  Lambda: Processor (Python 3.12, arm64/Graviton2)          │
│  1. Reads from SQS                                        │
│  2. Writes to DynamoDB with idempotency guard              │
│     ConditionExpression = "attribute_not_exists(order_id)" │
│     → First write: succeeds                               │
│     → Duplicate write: ConditionalCheckFailedException    │
│                        (treated as success — not an error) │
│  3. Publishes to SNS: order.confirmed                     │
└────────────────────┬───────────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────────┐
│  DynamoDB: orders table                                    │
│  Partition key: order_id (UUID)                            │
│  PAY_PER_REQUEST (no capacity planning needed)             │
│  Point-in-time recovery enabled (PITR)                    │
│  Encrypted at rest (SSE)                                   │
└────────────────────────────────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────────┐
│  SNS Topic + Email subscription                            │
│  "Your order ORD-123 has been confirmed!"                 │
└────────────────────────────────────────────────────────────┘
```

---

## The Two-Layer Idempotency System

This is the most important concept in this project. **Idempotency** means: running the same operation multiple times produces the same result as running it once.

**Why we need it:**
SQS guarantees *at-least-once* delivery. Under failure scenarios, the same message can be delivered more than once. Without protection, a customer could be charged twice for the same order.

**Layer 1 — SQS FIFO Deduplication (5-minute window):**
Every message has a `MessageDeduplicationId = order_id`. If SQS receives the same deduplication ID twice within 5 minutes, it drops the second one. The processor never even sees the duplicate.

**Layer 2 — DynamoDB Conditional Write:**
```python
table.put_item(
    Item=order,
    ConditionExpression="attribute_not_exists(order_id)"
    # If order_id already exists → raises ConditionalCheckFailedException
    # We CATCH this exception and treat it as SUCCESS (order already saved)
)
```
Even if Layer 1 fails (SQS delivers a duplicate after 5 minutes), Layer 2 catches it at the database level.

---

## Project Structure

```
event-driven-orders/
├── terraform/
│   ├── main.tf              ← Root — calls all modules
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
│       ├── api-gateway/     ← HTTP API + /orders route
│       ├── lambda/          ← Validator + Processor functions
│       │   └── functions/
│       │       ├── validator/handler.py    ← Validates + sends to SQS
│       │       └── processor/handler.py   ← Reads SQS + writes DynamoDB
│       ├── sqs/             ← FIFO queue + DLQ + SNS topic
│       ├── dynamodb/        ← Orders table
│       └── monitoring/      ← CloudWatch alarms + dashboard
├── bootstrap/main.tf
├── scripts/
│   ├── deploy.sh            ← Full deployment in one command
│   └── test-orders.sh       ← Send test orders + verify
└── .github/workflows/deploy.yml
```

---

## Step 1: Bootstrap

```bash
cd event-driven-orders/bootstrap
terraform ini
terraform apply
# Type "yes"
```

---

## Step 2: Configure Your Email (Required for Notifications)

```bash
cd ..
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars`:
```hcl
project_name  = "orders"
environment   = "dev"
aws_region    = "us-east-1"
alert_email   = "your-email@gmail.com"   # You MUST verify this in SES
```

**Verify your email with SES (required before SES can send you emails):**
```bash
aws ses verify-email-identity --email-address your-email@gmail.com --region us-east-1
# Check your inbox and click the verification link
```

---

## Step 3: Deploy

```bash
cd terraform
terraform ini
terraform plan  # Should show ~22-25 resources
terraform apply
# Type "yes"
# Takes ~3-4 minutes
```

**Expected outputs:**
```
api_url        = "https://abc123.execute-api.us-east-1.amazonaws.com"
orders_table   = "orders-dev-orders"
dlq_url        = "https://sqs.us-east-1.amazonaws.com/123/orders-dev-dlq.fifo"
dashboard_url  = "https://console.aws.amazon.com/cloudwatch/home#dashboards:name=orders-dev"
```

---

## Step 4: Test the System

```bash
# Run the automated test scrip
bash scripts/test-orders.sh

# OR test manually:
API_URL=$(cd terraform && terraform output -raw api_url)

# Place a valid order
curl -X POST "$API_URL/orders"
  -H "Content-Type: application/json"
  -d '{
    "customer_id": "CUST-001",
    "items": [
      {"product_id": "PROD-A", "quantity": 2, "unit_price": 29.99}
    ],
    "total_amount": 59.98
  }'

# Expected response (202 Accepted — order queued, not yet processed):
# {
#   "order_id": "550e8400-e29b-41d4-a716-446655440000",
#   "status": "queued",
#   "message": "Order received and queued for processing"
# }
```

---

## Step 5: Verify Zero Duplicate Orders

Send the SAME order twice rapidly:

```bash
# First order — should succeed
curl -X POST "$API_URL/orders"
  -H "Content-Type: application/json"
  -d '{"customer_id":"CUST-001","items":[{"product_id":"PROD-A","quantity":1,"unit_price":9.99}],"total_amount":9.99}'

# Same order immediately after — SQS FIFO deduplication catches i
curl -X POST "$API_URL/orders"
  -H "Content-Type: application/json"
  -d '{"customer_id":"CUST-001","items":[{"product_id":"PROD-A","quantity":1,"unit_price":9.99}],"total_amount":9.99}'

# Verify only ONE record in DynamoDB
aws dynamodb scan --table-name orders-dev-orders
  --query 'Count'
# Expected: 1 (not 2!)
```

---

## Step 6: Test Error Handling (DLQ)

Send an invalid order to trigger DLQ flow:

```bash
# Invalid order: missing required fields → validator rejects i
curl -X POST "$API_URL/orders"
  -H "Content-Type: application/json"
  -d '{"invalid": "data"}'
# Expected: 400 Bad Reques

# Check CloudWatch alarm state
aws cloudwatch describe-alarms
  --alarm-names "orders-dev-dlq-depth-alarm"
  --query 'MetricAlarms[].StateValue'
```

---

## Step 7: View the CloudWatch Dashboard

```bash
# Open the dashboard URL from terraform outpu
DASHBOARD=$(cd terraform && terraform output -raw dashboard_url)
echo "Open: $DASHBOARD"
```

The dashboard shows:
- Orders received per minute
- Validator errors
- Processor errors
- DLQ depth (should be 0!)
- Lambda duration (Graviton2 performance)

---

## Step 8: Understand the Lambda Code

Open `terraform/modules/lambda/functions/validator/handler.py`:

```python
def lambda_handler(event, context):
    # event["body"] contains the JSON sent by the customer
    body = json.loads(event.get("body", "{}"))

    # Validate required fields
    REQUIRED = {"customer_id", "items", "total_amount"}
    missing = REQUIRED - set(body.keys())
    if missing:
        return {"statusCode": 400, "body": json.dumps({"error": f"Missing: {missing}"})}

    # Generate unique order ID
    order_id = f"ORD-{uuid.uuid4()}"

    # Send to SQS FIFO — both IDs are REQUIRED for FIFO queues
    sqs.send_message(
        QueueUrl=os.environ["INTAKE_QUEUE_URL"],
        MessageBody=json.dumps({**body, "order_id": order_id}),
        MessageGroupId=body["customer_id"],   # Orders per customer are ordered
        MessageDeduplicationId=order_id       # 5-minute dedup window
    )

    # Return 202 Accepted (not 200 OK) — order is queued, not yet saved
    return {"statusCode": 202, "body": json.dumps({"order_id": order_id, "status": "queued"})}
```

---

## Step 9: DESTROY When Done

```bash
cd terraform
terraform destroy
# Type "yes"
```

---

## What to Say in an Interview

> "I built an event-driven order processing pipeline: API Gateway receives orders, a validator Lambda validates and sends to SQS FIFO, and a processor Lambda writes to DynamoDB. The critical design challenge was idempotency — SQS guarantees at-least-once delivery, so I implemented two layers of duplicate protection. Layer one: SQS FIFO MessageDeduplicationId with a 5-minute window. Layer two: DynamoDB conditional write with attribute_not_exists on the order ID — if a duplicate arrives, the condition fails silently and we treat it as success. Zero duplicate orders even under retry storms. I used a Dead Letter Queue with a CloudWatch alarm on depth greater than zero — any failed order that exhausts its 3 retries triggers an alert before the message is lost."
