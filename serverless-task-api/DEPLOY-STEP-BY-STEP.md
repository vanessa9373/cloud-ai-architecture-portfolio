# Project 3: Serverless Task API — Deployment Guide

> **Goal:** Build and deploy a full REST API with zero servers — Lambda + API Gateway + DynamoDB.
> **Time to complete:** ~20 minutes
> **AWS Cost estimate:** Effectively FREE under AWS free tier (1M Lambda requests/month free)
> **Monthly cost at 1M requests:** ~$2.32

---

## Architecture Diagram

```
You (curl / Postman / browser)
        │
        ▼
┌──────────────────────────────────────────────────────┐
│           API Gateway HTTP API                        │
│   POST /tasks  GET /tasks  GET /tasks/{id}           │
│   PATCH /tasks/{id}  DELETE /tasks/{id}              │
│           $1.00 per million requests                 │
└──────────────┬───────────────────────────────────────┘
               │  JWT token validated here
               ▼
┌──────────────────────────────────────────────────────┐
│           AWS Lambda Functions                        │
│   create_task │ get_task │ list_tasks                │
│   update_task │ delete_task                          │
│   Python 3.12 │ arm64 Graviton2 │ 20% cheaper        │
└──────────────┬───────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────┐
│           DynamoDB Table                              │
│   PAY_PER_REQUEST (pay per read/write, not per hour) │
│   Partition key: task_id (UUID)                      │
│   GSI: status-created_at-index (for filtering)       │
└──────────────────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────┐
│           X-Ray + CloudWatch                          │
│   Full request tracing │ Error metrics │ Dashboards  │
└──────────────────────────────────────────────────────┘
```

---

## What You Will Learn

- How serverless works (no servers to manage, pay only when code runs)
- Lambda handler structure (`lambda_handler(event, context)`)
- DynamoDB CRUD operations from Python (boto3)
- API Gateway routes and Lambda integrations
- Why PAY_PER_REQUEST is better than provisioned capacity for variable traffic
- How OIDC-based GitHub Actions CI/CD works (no stored AWS keys!)

---

## Prerequisites

```
[ ] AWS CLI configured (run: aws configure)
[ ] Terraform >= 1.6 installed
[ ] Python 3.12 installed (for local testing)
[ ] Git installed
[ ] Postman or curl for testing (curl comes pre-installed on Mac/Linux)
```

---

## Step 1: Understand the Project Structure

```
serverless-task-api/
├── src/
│   └── handlers/            ← Lambda function code (Python)
│       ├── create_task.py   ← POST /tasks
│       ├── get_task.py      ← GET /tasks/{id}
│       ├── list_tasks.py    ← GET /tasks
│       ├── update_task.py   ← PATCH /tasks/{id}
│       └── delete_task.py   ← DELETE /tasks/{id}
├── terraform/
│   ├── main.tf              ← Root config — calls all modules
│   ├── variables.tf         ← All configurable values
│   ├── outputs.tf           ← Values shown after deploy
│   └── modules/
│       ├── dynamodb/        ← Creates the DynamoDB table
│       ├── lambda/          ← Creates all 5 Lambda functions
│       └── api-gateway/     ← Creates the HTTP API + routes
├── bootstrap/
│   └── main.tf              ← Run ONCE to create S3 state bucke
├── tests/
│   └── test_create_task.py  ← Unit tests
└── .github/workflows/
    └── deploy.yml           ← CI/CD pipeline
```

**Key concept:** Each module (`dynamodb/`, `lambda/`, `api-gateway/`) is a reusable piece. The root `main.tf` connects them together like Lego blocks.

---

## Step 2: Run Bootstrap (One-Time Only)

```bash
# Navigate into the projec
cd serverless-task-api/bootstrap

# Initialize and apply
terraform ini
terraform apply
# Type "yes" when prompted

# Expected output:
# Apply complete! Resources: 4 added.
# Outputs:
# state_bucket_name = "vanessa-terraform-state"
```

---

## Step 3: Configure Variables

```bash
# Go back to roo
cd ..

# Copy the example variables file
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars`:

```hcl
project_name = "task-api"
environment  = "dev"
aws_region   = "us-east-1"
alert_email  = "your-email@gmail.com"
```

---

## Step 4: Deploy

```bash
cd terraform

# Initialize (downloads providers and modules)
terraform ini

# Preview what will be created (~15-20 resources)
terraform plan

# Deploy!
terraform apply
# Type "yes" when prompted
# Takes ~2-3 minutes (much faster than HA WordPress!)
```

**Expected output:**
```
Apply complete! Resources: 18 added, 0 changed, 0 destroyed.

Outputs:
api_url = "https://abc123.execute-api.us-east-1.amazonaws.com"
dynamodb_table = "task-api-dev-tasks"
```

---

## Step 5: Test Your API

Copy the `api_url` from the output above. Replace `YOUR_API_URL` below.

### Create a Task
```bash
# POST /tasks — creates a new task
curl -X POST https://YOUR_API_URL/tasks
  -H "Content-Type: application/json"
  -d '{
    "title": "Learn AWS Lambda",
    "description": "Deploy my first serverless function",
    "priority": "high"
  }'

# Expected response:
# {
#   "task_id": "550e8400-e29b-41d4-a716-446655440000",
#   "title": "Learn AWS Lambda",
#   "status": "pending",
#   "created_at": "2026-07-16T12:00:00Z"
# }
```

### List All Tasks
```bash
# GET /tasks — returns all tasks
curl https://YOUR_API_URL/tasks

# Expected response:
# {
#   "tasks": [...],
#   "count": 1
# }
```

### Get a Specific Task
```bash
# Replace TASK_ID with the task_id from the create response
curl https://YOUR_API_URL/tasks/TASK_ID
```

### Update a Task
```bash
curl -X PATCH https://YOUR_API_URL/tasks/TASK_ID
  -H "Content-Type: application/json"
  -d '{"status": "completed"}'
```

### Delete a Task
```bash
curl -X DELETE https://YOUR_API_URL/tasks/TASK_ID
# Expected response: {"message": "Task deleted successfully"}
```

---

## Step 6: Understand What the Lambda Code Does

Open `src/handlers/create_task.py`:

```python
import json
import uuid
import boto3
from datetime import datetime, timezone

# boto3 is the Python SDK for AWS — like an API client for all AWS services
dynamodb = boto3.resource("dynamodb")

def lambda_handler(event, context):
    """
    AWS Lambda calls this function for every API request.

    event = the HTTP request (method, headers, body, path params)
    context = Lambda metadata (function name, timeout remaining, etc.)
    """
    # Parse the JSON body sent by the clien
    body = json.loads(event.get("body", "{}"))

    # Validate required field
    if "title" not in body:
        return {"statusCode": 400, "body": json.dumps({"error": "title is required"})}

    # Create a unique ID for this task (UUID = Universally Unique ID)
    task_id = str(uuid.uuid4())

    # Build the item to store in DynamoDB
    item = {
        "task_id": task_id,
        "title": body["title"],
        "status": "pending",                          # Default status
        "created_at": datetime.now(timezone.utc).isoformat()
    }

    # Write to DynamoDB
    table = dynamodb.Table("task-api-dev-tasks")
    table.put_item(Item=item)

    # Return HTTP 201 Created with the new task
    return {
        "statusCode": 201,
        "body": json.dumps(item)
    }
```

**Key concept — why Lambda instead of EC2?**
- EC2: you pay 24/7 even when nobody is using the API
- Lambda: you pay ONLY when the API is called (per 1ms of execution time)
- At 1M requests/month: Lambda costs ~$2.32. EC2 t3.micro would cost ~$8.40/month even with zero traffic.

---

## Step 7: Check Logs and Traces

### View Lambda logs in CloudWatch
```bash
# See recent logs from the create_task function
aws logs tail /aws/lambda/task-api-dev-create-task --since 1h --format shor
```

### View X-Ray traces (distributed request tracing)
```bash
# Get trace IDs from the last hour
aws xray get-trace-summaries
  --time-range-type TimeRangeByEdge
  --start-time $(date -u -v-1H +%s)
  --end-time $(date -u +%s)
  --query 'TraceSummaries[].Id'
  --output tex
```

Or go to AWS Console → X-Ray → Traces to see a visual trace map.

---

## Step 8: Run Unit Tests

```bash
# Install Python test dependencies
pip install pytest boto3 moto

# Run tests
cd ..
pytest tests/ -v

# Expected output:
# tests/test_create_task.py::test_create_task_success PASSED
# tests/test_create_task.py::test_create_task_missing_title PASSED
# 2 passed in 0.45s
```

---

## Step 9: Deploy via GitHub Actions (CI/CD)

After pushing to your GitHub fork:
1. Every PR shows a `terraform plan` as a PR commen
2. Every merge to `main` triggers `terraform apply` automatically

**Setup required:**
1. Go to GitHub repo → Settings → Actions → Secrets
2. Add: `AWS_ROLE_ARN` = your IAM role ARN (from OIDC setup)

---

## Step 10: DESTROY When Done

```bash
cd terraform
terraform destroy
# Type "yes"
```

---

## Key DynamoDB Concepts to Know

| Concept | What it means |
|---------|--------------|
| **PAY_PER_REQUEST** | You pay per read/write unit consumed, not per hour. Perfect for variable traffic. |
| **Partition key** | Like a primary key in SQL. DynamoDB distributes data across partitions based on this. |
| **GSI (Global Secondary Index)** | Like adding a secondary index to a SQL table. Lets you query on non-key attributes. |
| **Scan vs Query** | Query = efficient (uses key). Scan = reads entire table (slow and expensive). Always Query. |

---

## What to Say in an Interview

> "I built a full CRUD REST API on serverless infrastructure — API Gateway HTTP API routing requests to five Lambda functions in Python 3.12 on Graviton2, writing to DynamoDB PAY_PER_REQUEST. The HTTP API costs $1 per million requests versus $3.50 for the REST API, and running on Graviton2 arm64 is 20% cheaper than x86 Lambda. The whole system costs approximately $2.32 per month at one million requests per month — compared to an equivalent EC2+RDS setup that would cost around $40-50 per month including idle capacity. The CI/CD pipeline uses GitHub Actions with OIDC authentication — no long-lived AWS credentials stored anywhere."
