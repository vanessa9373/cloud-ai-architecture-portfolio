# Project 1: HA WordPress on AWS — Deployment Guide

> **Goal:** Deploy a production-grade, zero-SPOF WordPress site across 3 AWS Availability Zones using Terraform.
> **Time to complete:** ~45 minutes
> **AWS Cost estimate:** ~$0.15/hour while running (destroy when done!)

---

## Architecture Diagram

```
Interne
    │
    ▼
┌─────────────────────────────────────────────────────┐
│                  CloudFront CDN                      │
│              (Global edge caching)                   │
│                    WAF Rules                         │
│           (OWASP Top 10 + SQLi blocked)              │
└─────────────────────┬───────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│          Application Load Balancer (ALB)             │
│              (us-east-1 — 3 AZs)                    │
└────────┬────────────┬────────────┬───────────────────┘
         │            │            │
         ▼            ▼            ▼
    ┌────────┐   ┌────────┐   ┌────────┐
    │  EC2   │   │  EC2   │   │  EC2   │  Auto Scaling Group
    │  AZ-a  │   │  AZ-b  │   │  AZ-c  │  (min:2, max:6)
    └────┬───┘   └────┬───┘   └────┬───┘
         │            │            │
         └────────────┴────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│              RDS MySQL Multi-AZ                      │
│      Primary (AZ-a) ←→ Standby (AZ-b)              │
│   Synchronous replication | Auto failover <2 min    │
│              KMS Encrypted at rest                   │
└─────────────────────────────────────────────────────┘
```

---

## What You Will Learn

- How Terraform modules work (calling a module = using a reusable building block)
- How VPC subnets, security groups, and routing work together
- How RDS Multi-AZ provides automatic failover
- How CloudFront + WAF protects your application
- How Auto Scaling replaces unhealthy instances automatically

---

## Prerequisites Checklis

Before you start, make sure you have ALL of these:

```
[ ] AWS Account (free tier is fine to start, but this project WILL incur small costs)
[ ] AWS CLI installed → https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
[ ] Terraform installed (version >= 1.6) → https://developer.hashicorp.com/terraform/install
[ ] Git installed → https://git-scm.com/downloads
[ ] A code editor (VS Code recommended)
[ ] This repo cloned to your computer
```

---

## Step 1: Verify Your Tools Are Installed

Run each command and confirm you see a version number:

```bash
# Check AWS CLI
aws --version
# Expected output: aws-cli/2.x.x Python/3.x.x ...

# Check Terraform
terraform version
# Expected output: Terraform v1.6.x ...

# Check Gi
git --version
# Expected output: git version 2.x.x
```

If any command fails with "command not found", install that tool first.

---

## Step 2: Configure AWS Credentials

This tells Terraform which AWS account to use.

```bash
# Run this command — it will prompt you for 4 things:
aws configure
```

You'll be asked for:
```
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE     ← Your Access Key (from AWS Console)
AWS Secret Access Key [None]: wJalrXUt...           ← Your Secret Key (from AWS Console)
Default region name [None]: us-east-1               ← Type: us-east-1
Default output format [None]: json                   ← Type: json
```

**How to get your Access Key:**
1. Go to AWS Console → Click your name (top right) → "Security credentials"
2. Scroll to "Access keys" → "Create access key"
3. Copy the Access Key ID and Secret Access Key

**Verify it worked:**
```bash
aws sts get-caller-identity
# Expected output:
# {
#     "UserId": "AIDA...",
#     "Account": "123456789012",
#     "Arn": "arn:aws:iam::123456789012:user/your-username"
# }
```

---

## Step 3: Run the Bootstrap (One-Time Setup)

The bootstrap creates the S3 bucket and DynamoDB table that Terraform uses to store its state file. This MUST be done before anything else.

**Why do we need this?**
Terraform keeps track of what it has created in a "state file." We store this in S3 so:
- Multiple people can work on the same infrastructure
- Terraform knows what exists vs what needs to be created
- DynamoDB prevents two people from running Terraform at the same time (locking)

```bash
# Navigate to the bootstrap folder
cd ha-wordpress-terraform/bootstrap

# Initialize Terraform (downloads the AWS provider plugin)
terraform ini

# See what will be created (always preview before applying!)
terraform plan

# Create the S3 bucket and DynamoDB table
terraform apply
# When prompted: type "yes" and press Enter
```

**Expected output after apply:**
```
Apply complete! Resources: 4 added, 0 changed, 0 destroyed.

Outputs:
state_bucket_name = "vanessa-terraform-state"
lock_table_name = "terraform-state-lock"
```

**IMPORTANT:** You only run bootstrap ONCE ever. Never run it again or delete it.

---

## Step 4: Configure Your Variables

Go back to the main project folder:

```bash
cd ..
```

Open the file `variables.tf` — this is where all the configuration lives. You need to change these values:

```bash
# Create your personal variables file (copy from the example)
cp terraform.tfvars.example terraform.tfvars
```

Now open `terraform.tfvars` in your editor and update:

```hcl
# Your AWS region — us-east-1 is recommended
aws_region = "us-east-1"

# A name for this project (no spaces, lowercase)
project_name = "wp-ha"

# Environment: dev, staging, or prod
environment = "dev"

# Your domain name — if you don't have one, use a fake one for learning
# (CloudFront/ACM won't work without a real domain, but everything else will)
domain_name = "yourdomain.com"

# Email for cost/alert notifications
alert_email = "your-email@gmail.com"

# Database name (no spaces, letters and underscores only)
db_name = "wordpress"

# Database username
db_username = "wpuser"

# EC2 key pair name — see Step 4a below if you don't have one
ec2_key_pair_name = "my-key-pair"
```

### Step 4a: Create an EC2 Key Pair (if you don't have one)

An EC2 key pair lets you SSH into your servers if needed.

```bash
# Create a new key pair and save it locally
aws ec2 create-key-pair
  --key-name my-key-pair
  --query 'KeyMaterial'
  --output text > my-key-pair.pem

# Set correct permissions (required on Mac/Linux)
chmod 400 my-key-pair.pem

# Verify it was created
aws ec2 describe-key-pairs --key-names my-key-pair
```

---

## Step 5: Initialize Terraform

This downloads all the Terraform modules and providers your configuration needs.

```bash
# Make sure you're in the ha-wordpress-terraform folder (not bootstrap)
pwd
# Should show: .../ha-wordpress-terraform

# Initialize
terraform ini
```

**Expected output:**
```
Initializing the backend...
Initializing modules...
- module.vpc
- module.security
- module.compute
- module.database
- module.cdn
- module.monitoring
...
Terraform has been successfully initialized!
```

**What this does:**
- Downloads the AWS provider (the code that talks to AWS API)
- Downloads each module your main.tf references
- Connects to the S3 backend you created in Step 3

---

## Step 6: Preview What Will Be Created

Always run `plan` before `apply`. It shows exactly what Terraform will create/change/destroy.

```bash
terraform plan
```

**Read the output carefully:**
- Lines starting with `+` = will be CREATED (green)
- Lines starting with `-` = will be DESTROYED (red)
- Lines starting with `~` = will be MODIFIED (yellow)

You should see approximately **40-50 resources** planned including:
- 1 VPC
- 3 public subnets, 3 private subnets, 3 database subnets
- Internet Gateway, NAT Gateways
- Security Groups for ALB, EC2, and RDS
- Application Load Balancer
- Auto Scaling Group with Launch Template
- RDS MySQL Multi-AZ instance
- CloudFront distribution
- WAF Web ACL
- KMS key
- CloudWatch alarms
- S3 bucket for media

---

## Step 7: Deploy the Infrastructure

```bash
terraform apply
```

When prompted: **type `yes` and press Enter**

**This will take approximately 15-25 minutes.** RDS is the slowest part (~15 min to provision).

Watch the output — you'll see resources being created in real time:
```
aws_vpc.main: Creating...
aws_vpc.main: Creation complete after 2s [id=vpc-0abc...]
aws_subnet.public[0]: Creating...
...
module.database.aws_db_instance.wordpress: Creating...
module.database.aws_db_instance.wordpress: Still creating... [10s elapsed]
module.database.aws_db_instance.wordpress: Still creating... [15m0s elapsed]
module.database.aws_db_instance.wordpress: Creation complete after 15m32s
```

---

## Step 8: Check Your Outputs

After apply completes, run:

```bash
terraform outpu
```

You'll see:
```
alb_dns_name = "wp-ha-prod-alb-123456789.us-east-1.elb.amazonaws.com"
cloudfront_domain = "d1234567890.cloudfront.net"
rds_endpoint = "wp-ha-prod.abc123.us-east-1.rds.amazonaws.com:3306"
```

---

## Step 9: Verify Everything Is Working

```bash
# Run the automated test scrip
bash scripts/test.sh
```

Or test manually:

```bash
# 1. Check if the ALB is healthy
ALB_DNS=$(terraform output -raw alb_dns_name)
curl -I http://$ALB_DNS
# Expected: HTTP/1.1 200 OK (or 302 redirect to HTTPS)

# 2. Check Auto Scaling Group
aws autoscaling describe-auto-scaling-groups
  --query 'AutoScalingGroups[].{Name:AutoScalingGroupName, Min:MinSize, Max:MaxSize, Desired:DesiredCapacity, Healthy:HealthyInstances}'

# 3. Check RDS is Multi-AZ
aws rds describe-db-instances
  --query 'DBInstances[].{ID:DBInstanceIdentifier, MultiAZ:MultiAZ, Status:DBInstanceStatus}'
# MultiAZ should be: true
```

---

## Step 10: Understand What You Buil

### Why 3 Availability Zones?
If AWS loses an entire data center (AZ), your site stays up. With 3 AZs, you can survive 2 simultaneous AZ failures.

### Why RDS Multi-AZ?
AWS runs a synchronized copy of your database in a second AZ. If the primary fails, AWS automatically fails over to the standby in ~2 minutes — no data loss (RPO < 30 seconds).

### Why CloudFront + WAF?
- CloudFront caches your content at 400+ edge locations worldwide → faster load times
- WAF blocks SQL injection, XSS, and other OWASP Top 10 attacks before they reach your servers

### Why Auto Scaling?
If traffic spikes (Black Friday, viral post), new EC2 instances launch automatically. If an instance fails health checks, it's replaced automatically.

---

## Step 11: Test Failover (Optional — Advanced)

This simulates what happens when an RDS instance fails:

```bash
# Trigger manual RDS failover (simulates AZ failure)
aws rds reboot-db-instance
  --db-instance-identifier wp-ha-dev
  --force-failover

# Watch the failover happen (refresh every 10 seconds)
watch -n 10 'aws rds describe-db-instances
  --query "DBInstances[].{Status:DBInstanceStatus, AZ:AvailabilityZone}"'

# Failover typically completes in 60-120 seconds
```

---

## Step 12: DESTROY (Always do this when done practicing!)

AWS charges by the hour. Always destroy when you're not using it.

```bash
terraform destroy
# When prompted: type "yes" and press Enter
```

**This takes ~10 minutes.** Wait for it to complete fully.

Verify nothing is left running:
```bash
aws ec2 describe-instances --filters "Name=instance-state-name,Values=running"
  --query 'Reservations[].Instances[].InstanceId'
# Should return: []
```

---

## Common Errors and Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `Error: No valid credential sources found` | AWS credentials not configured | Run `aws configure` again |
| `Error: Bucket does not exist` | Bootstrap not run | Run bootstrap first (Step 3) |
| `Error: Error creating Auto Scaling Group` | EC2 key pair doesn't exist | Run Step 4a to create key pair |
| `Error: InvalidParameterValue: DB instance class not supported` | Instance type not available in your region | Change `db_instance_class` to `db.t3.micro` |
| `Error: timeout while waiting for state to become 'available'` | AWS is slow | Run `terraform apply` again (idempotent) |

---

## What to Say in an Interview About This Projec

> "I built a production-grade three-tier WordPress architecture using Terraform, deployed across three Availability Zones. The compute layer uses an EC2 Auto Scaling Group behind an Application Load Balancer. The database layer uses RDS MySQL Multi-AZ with synchronous replication — if the primary fails, AWS automatically fails over to the standby in under two minutes, giving me an RTO of under 15 minutes and an RPO of under 30 seconds. CloudFront caches globally and WAF enforces OWASP Top 10 rules at the edge. Everything is provisioned as code in Terraform with a remote state backend in S3 and DynamoDB state locking."

---

## Architecture Decision Records (Why I Made These Choices)

**ADR-001: Why RDS Multi-AZ over single-AZ?**
- Single-AZ: ~$50/month, but one AZ failure = complete outage
- Multi-AZ: ~$100/month, but automatic failover in 2 minutes
- Decision: Multi-AZ. A single outage during peak traffic costs more than the $50/month premium.

**ADR-002: Why CloudFront in front of ALB?**
- ALB alone: all traffic hits your EC2 instances, including static files
- CloudFront: caches static content at edge, reduces EC2 load by ~70%
- Decision: CloudFront. Cost reduction pays for itself in EC2 compute savings.

**ADR-003: Why WAF on CloudFront, not ALB?**
- WAF on ALB: blocks at the application layer (traffic already reached your VPC)
- WAF on CloudFront: blocks at the edge (traffic never reaches your infrastructure)
- Decision: CloudFront WAF. Blocks attacks at the global edge — the attacker's request is rejected closest to the attacker.
