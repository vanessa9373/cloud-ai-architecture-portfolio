<div align="center">

# Vanessa Awo — Cloud & AI Architecture Portfolio

**Solutions Architect · Solutions Engineer · AI/ML Solutions Architect · Cloud Engineer · SRE · DevOps Engineer**

[![LinkedIn](https://img.shields.io/badge/LinkedIn-vanessajen-0A66C2?style=flat&logo=linkedin&logoColor=white)](https://linkedin.com/in/vanessajen)
[![AWS SAA-C03](https://img.shields.io/badge/AWS_SAA--C03-Certified-FF9900?style=flat&logo=amazonaws&logoColor=white)](#certifications-and-technical-skills)
[![ITIL 4](https://img.shields.io/badge/ITIL_4_Foundation-Certified-6B21A8?style=flat&logoColor=white)](#certifications-and-technical-skills)
[![Terraform](https://img.shields.io/badge/Terraform-IaC-7B42BC?style=flat&logo=terraform&logoColor=white)](https://terraform.io)
[![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-CI/CD-2088FF?style=flat&logo=githubactions&logoColor=white)](https://github.com/features/actions)

</div>

---

## What's In This Repo

Cloud and AI infrastructure projects demonstrating hands-on skills across Solutions
Architecture, AI/ML Solutions Architecture, Cloud Engineering, DevOps, and SRE disciplines.

Every project is labeled with an honest status — **Working implementation**, **Locally tested
prototype**, **Deployment-ready architecture**, **Architecture case study**, or **Work in
progress** — and separates measured results from design targets. Nothing here claims a
deployment that doesn't exist.

---

## Portfolio Navigation

### Featured Projects
| Project | Status | What it demonstrates |
|---|---|---|
| [StyleFind Visual Search](https://github.com/vanessa9373/stylefind-visual-search) | Locally tested prototype | Visual product search: embeddings, vector search, reranking, AWS multi-region design |
| [HA WordPress on AWS](#1-ha-wordpress-on-aws) | Deployment-ready architecture | Zero-SPOF 3-tier design, full Terraform |
| [Multi-Account Landing Zone](#2-multi-account-aws-landing-zone) | Deployment-ready architecture | AWS Organizations, SCPs, centralized governance |
| [EKS Microservices Platform](#5-eks-microservices-platform) | Deployment-ready architecture | GitOps, 11-service deployment, Karpenter |

### Cloud Architecture
[HA WordPress](#1-ha-wordpress-on-aws) · [Multi-Account Landing Zone](#2-multi-account-aws-landing-zone) · [NexaShop E-Commerce](#4-nexashop-e-commerce-platform) · [AWS APAC Forage SA](#6-aws-apac-solutions-architecture-simulation) · [IaC Environment Automation](#9-iac-environment-automation)

### AI and Machine Learning
[StyleFind Visual Search](https://github.com/vanessa9373/stylefind-visual-search) — visual product search API (embeddings, vector search, reranking). Status: locally tested prototype; AWS deployment is a documented design, not deployed. See its [model card](https://github.com/vanessa9373/stylefind-visual-search/blob/main/docs/model-card.md) and [limitations](https://github.com/vanessa9373/stylefind-visual-search/blob/main/docs/limitations.md).

### DevOps and SRE
[CI/CD Pipeline Automation](#8-cicd-pipeline-automation) · [Kubernetes Microservices Deployment](#10-kubernetes-microservices-deployment) · [EKS Microservices Platform](#5-eks-microservices-platform) · [Event-Driven Order Processing](#7-event-driven-order-processing) · [19 Hands-On Labs](#labs)

### System Design
[Architecture Case Studies](#architecture-case-studies) — 6 Solutions Architect design exercises (scenario-based, clearly labeled as practice exercises, not deployed systems).

### Business and Nonprofit Technology
Not yet published in this repo — planned, not built. Will not appear here until real, sanitized
content exists (no placeholder projects).

### Certifications and Technical Skills
See [Certifications](#certifications-and-technical-skills) and [Tech Stack](#tech-stack) below.

### Architecture Diagrams
Each project's `diagrams/` or inline Mermaid sections — linked from its own README. StyleFind's:
[diagrams/architecture.md](https://github.com/vanessa9373/stylefind-visual-search/blob/main/diagrams/architecture.md).

### Live Demos
None hosted yet — every prototype here runs locally (`uvicorn`, Docker) rather than being
deployed to avoid unapproved cloud spend. See each project's own deployment docs for exact
run instructions.

### Contact Information
See [Contact](#contact) below.

---

## Projects at a Glance

| # | Project | Key Services | Highlights |
|---|---------|-------------|------------|
| 1 | [HA WordPress](#1-ha-wordpress-on-aws) | EC2 ASG · RDS Multi-AZ · CloudFront · WAF | Zero-SPOF · 3 AZs · Full IaC |
| 2 | [Multi-Account Landing Zone](#2-multi-account-aws-landing-zone) | AWS Organizations · SCPs · Transit Gateway · IAM Identity Center | 8 SCPs · 10+ accounts · SAML SSO |
| 3 | [Serverless Task API](#3-serverless-task-api) | Lambda · API Gateway · DynamoDB · Cognito | 90% cheaper than EC2+RDS · ~$2.32/mo |
| 4 | [NexaShop E-Commerce](#4-nexashop-e-commerce-platform) | Lambda · Aurora · DynamoDB · ElastiCache · SQS | Polyglot persistence · 10M+ users |
| 5 | [EKS Online Boutique](#5-eks-microservices-platform) | EKS · ArgoCD · Prometheus · Karpenter · Trivy | GitOps · 11 microservices · 5 languages |
| 6 | [AWS APAC Forage SA](#6-aws-apac-solutions-architecture-simulation) | Elastic Beanstalk · RDS · CloudFront · Route 53 | Full pre-sales motion · Forage certified |
| 7 | [Event-Driven Order Processing](#7-event-driven-order-processing) | API Gateway · SQS FIFO · Lambda · DynamoDB | Zero duplicate orders · idempotent writes |
| 8 | [CI/CD Pipeline Automation](#8-cicd-pipeline-automation) | GitHub Actions · ECS Fargate · ECR · Trivy | OIDC auth · auto rollback on failed smoke test |
| 9 | [IaC Environment Automation](#9-iac-environment-automation) | Terraform modules · VPC · EC2 · RDS · SSM | 3 environments, isolated state, no SSH keys |
| 10 | [Kubernetes Microservices Deployment](#10-kubernetes-microservices-deployment) | EKS · HPA · Container Insights | Multi-service app, self-scaling, IRSA-scoped observability |

**Plus:** [19 hands-on labs](#labs) — Kubernetes, GitOps, chaos engineering, SRE, FinOps, security, observability
**Plus:** [6 architecture case studies](#architecture-case-studies) — SA design exercises across e-commerce, SaaS, fintech, media, ridesharing, and image processing

---

## Project Details

### 1. HA WordPress on AWS

> `./ha-wordpress-terraform`

Production-grade, zero-SPOF 3-tier architecture across 3 Availability Zones — designed around the AWS Well-Architected Framework.

| Component | Implementation |
|-----------|---------------|
| **IaC** | Terraform — full infrastructure as code, reproducible in one command |
| **Compute** | EC2 Auto Scaling Group behind Application Load Balancer |
| **Database** | RDS MySQL Multi-AZ — synchronous replication, <2 min automatic failover |
| **CDN** | CloudFront + S3 OAC for global content delivery |
| **Security** | WAF (OWASP/SQLi rules), IMDSv2, KMS CMK encryption, SSM Session Manager |
| **Monitoring** | CloudWatch alarms on p99 latency, 5xx rate, RDS connections |

**SA angle:** Well-Architected review across all 6 pillars with explicit trade-off docs
**Cloud Engineer angle:** Full Terraform module structure with remote state and DynamoDB locking

---

### 2. Multi-Account AWS Landing Zone

> `./multi-account-landing-zone`

Enterprise-grade multi-account governance — the foundational architecture every organization needs before scaling workloads on AWS.

| Component | Implementation |
|-----------|---------------|
| **Structure** | 4 OUs (Management, Security, Infrastructure, Workloads) · 10+ accounts |
| **Governance** | 8 SCPs — DenyRootUser, RequireIMDSv2, AllowedRegionsOnly, DenyPublicS3 |
| **Networking** | Transit Gateway hub-and-spoke · Prod↔Dev network isolation |
| **Identity** | SAML 2.0 SSO via IAM Identity Center |
| **Security** | GuardDuty + Security Hub centralized across all member accounts |

**SA angle:** Governance-first design — built for a team scaling from 1 to 50+ accounts
**SRE angle:** Centralized logging and security aggregation as operational foundation

---

### 3. Serverless Task API

> `./serverless-task-api`

Full CRUD REST API on serverless architecture with CI/CD — 90% cost reduction vs equivalent EC2+RDS.

| Component | Implementation |
|-----------|---------------|
| **Compute** | Lambda functions on Graviton2/arm64 — 20% cheaper than x86 |
| **API** | API Gateway HTTP API — $1.00/M requests vs REST API $3.50/M |
| **Database** | DynamoDB PAY_PER_REQUEST + GSI for status-based queries |
| **Auth** | Cognito User Pools — JWT validation on every endpoint |
| **CI/CD** | GitHub Actions with OIDC auth — no long-lived AWS keys |
| **Est. cost** | ~$2.32/month at 1M requests/month |

**SA angle:** Cost model comparison vs EC2+RDS — quantified TCO for the architecture decision
**DevOps angle:** OIDC-based GitHub Actions pipeline with zero stored credentials

---

### 4. NexaShop E-Commerce Platform

> `./nexashop-ecommerce`

Cloud-native e-commerce platform designed for 10M+ users — polyglot persistence, decoupled order processing, full CI/CD.

| Component | Implementation |
|-----------|---------------|
| **Frontend** | React → S3 + CloudFront (OAC) + WAF (OWASP Top 10 + rate limiting) |
| **API** | Lambda + API Gateway · Cognito JWT auth · X-Ray tracing |
| **Catalog DB** | DynamoDB PAY_PER_REQUEST + category GSI for browse queries |
| **Orders DB** | Aurora PostgreSQL Multi-AZ — ACID transactions, <30s failover |
| **Sessions** | ElastiCache Redis — sub-millisecond cart reads, TTL-based expiry |
| **Order pipeline** | SQS decoupled processing + DLQ + SES confirmation email |
| **CI/CD** | GitHub Actions: Lambda zip → ECS Fargate → S3 sync → CloudFront invalidation |
| **Est. cost** | ~$297/month vs ~$1,800/month on-prem equivalent |

**SA angle:** Polyglot persistence — right database for each workload with explicit ADRs
**Cloud Engineer angle:** End-to-end CI/CD pipeline across Lambda, ECS, and S3

---

### 5. EKS Microservices Platform

> `./eks-online-boutique`

Full DevOps lifecycle for 11 real microservices across Go, Python, Java, C#, and Node.js — every production pattern implemented.

| Component | Implementation |
|-----------|---------------|
| **Infrastructure** | Terraform: VPC (3 AZs) · EKS 1.28 · ECR (11 repos) · IRSA roles |
| **CI/CD** | GitHub Actions (OIDC): build → Trivy CVE scan → ECR push → manifest update |
| **GitOps** | ArgoCD: auto-sync from Git, drift detection, rollback via `git revert` |
| **Observability** | Prometheus + Grafana (golden signals) · CloudWatch Container Insights · X-Ray |
| **Security** | Trivy blocks CRITICAL CVEs · RBAC · NetworkPolicies · External Secrets Operator |
| **Autoscaling** | Karpenter: node provisioning <60s · ~30% cost reduction vs static node groups |

**DevOps angle:** Complete GitOps workflow from code commit to production deployment
**SRE angle:** Golden signals observability with automated alerting and Karpenter cost optimization

---

### 6. AWS APAC Solutions Architecture Simulation

> `./aws-apac-forage`

Simulated full SA/SE engagement — from technical discovery to architecture design to stakeholder presentation. Certified by AWS × Forage.

| Component | Implementation |
|-----------|---------------|
| **Discovery** | Mapped single-EC2 architecture, identified all single points of failure |
| **Architecture** | Elastic Beanstalk + RDS Multi-AZ + CloudFront (PriceClass_200) + Route 53 |
| **Communication** | Restaurant analogy to explain Auto Scaling to a non-technical client |
| **Objection handling** | Reframed $70→$280/month cost as risk elimination: 3 outages × $5K = $15K/quarter risk |
| **ADRs** | Elastic Beanstalk over EKS (right-sized for client ops capability) |

**SA/SE angle:** Demonstrates the complete pre-sales motion — discovery → design → communication → objection handling

---

### 7. Event-Driven Order Processing

> `./event-driven-orders`

Order intake API → SQS FIFO → Lambda processor → DynamoDB, with zero duplicate orders guaranteed under retry.

| Component | Implementation |
|-----------|---------------|
| **API** | API Gateway HTTP API — validator Lambda returns `202 Accepted` immediately |
| **Queue** | SQS FIFO — `MessageGroupId` per customer, `MessageDeduplicationId` per order (5-min window) |
| **Reliability** | Dead-letter queue after 3 failed attempts + CloudWatch alarm on DLQ depth |
| **Idempotency** | Processor Lambda writes to DynamoDB with `ConditionExpression = attribute_not_exists(order_id)` |
| **Compute** | Python 3.12 on Graviton2/arm64 for both validator and processor |

**SA angle:** Exactly-once processing semantics built from at-least-once primitives (SQS + conditional writes)
**DevOps angle:** Fully serverless, effectively free at learning-volume traffic

---

### 8. CI/CD Pipeline Automation

> `./cicd-pipeline-automation`

End-to-end pipeline that builds, tests, containerizes, and deploys a Node.js API to AWS ECS Fargate, with automatic rollback on a failed deployment.

| Component | Implementation |
|-----------|---------------|
| **Test** | `npm ci` → ESLint → Jest (unit tests + coverage) |
| **Build** | Docker build → Trivy image scan → push to Amazon ECR |
| **Deploy** | Render task def → `ecs update-service` → wait for steady state → smoke test `/health` via ALB |
| **Rollback** | Failed smoke test auto-reverts the ECS service to the previous task definition |
| **Environments** | Staging auto-deploys on push to `main`; production requires a manual GitHub Environment approval gate |
| **Auth** | GitHub OIDC deploy role — no long-lived AWS keys stored in the repo |

**DevOps angle:** Full staged rollout with an automatic, tested rollback path — not just a deploy script

---

### 9. IaC Environment Automation

> `./iac-environment-automation`

Reusable Terraform modules (VPC, security groups, IAM, EC2, RDS) composed into three isolated environments — `./scripts/deploy-environment.sh <env>` instead of a manual console checklist.

| Component | Implementation |
|-----------|---------------|
| **Structure** | `terraform/modules/*` (DRY) composed by `terraform/environments/{dev,staging,prod}` (thin, isolated) |
| **State isolation** | Each environment has its own S3 state key — a `dev` mistake structurally cannot touch `prod` |
| **Access** | SSM Session Manager only — no SSH keys to rotate or leak, port 22 closed by default in every environment |
| **Secrets** | RDS `manage_master_user_password = true` — AWS-managed via Secrets Manager, never a plaintext Terraform variable |

**Cloud Engineer angle:** Environment parity through composition, not copy-paste — explicit design-decision writeups for each trade-off

---

### 10. Kubernetes Microservices Deployment

> `./kubernetes-microservices-deployment`

A production-shaped EKS cluster, entirely from Terraform, running a multi-service app that scales itself under load.

| Component | Implementation |
|-----------|---------------|
| **Infrastructure** | Terraform: VPC (2 AZ) · EKS control plane · managed node group in private subnets |
| **Add-ons** | `vpc-cni`, `kube-proxy`, `coredns`, `metrics-server`, `amazon-cloudwatch-observability` |
| **App** | frontend (nginx) → backend (go-httpbin) → redis, each with HPA scaling on CPU > 60% |
| **Observability** | IRSA-scoped `CloudWatchAgentServerPolicy` — pod-level permissions, not node-wide |

**DevOps angle:** Cluster and workload both defined and scaled without a single hand-written DaemonSet

---

## Architecture Case Studies

> `./architecture-case-studies`

Six Solutions Architect design exercises: a realistic business scenario, a full architecture
designed against it, and the Terraform to back the design. **These are practice exercises, not
deployed production systems** — the client names and figures are illustrative, used to reason
about trade-offs the way a real engagement would require. See
[`architecture-case-studies/README.md`](./architecture-case-studies/README.md) for the full
breakdown of each.

| Scenario | Focus |
|---|---|
| [E-Commerce Platform](./architecture-case-studies/ecommerce-platform) | Multi-region HA/DR, PCI-DSS, flash-sale traffic spikes |
| [SaaS Platform](./architecture-case-studies/saas-platform) | Multi-tenant serverless, Cognito, per-tenant isolation |
| [Fintech Data Lake](./architecture-case-studies/fintech-data-lake) | S3 data lake, Glue, Athena, PCI data handling |
| [Media Platform](./architecture-case-studies/media-platform) | CloudFront + MediaConvert at global scale |
| [Ridesharing Platform](./architecture-case-studies/ridesharing-platform) | Real-time location data, Cognito, Lambda |
| [PixelVault (Image Processing)](./architecture-case-studies/pixelvault-platform) | Event-driven image pipeline, storage/compute trade-offs |

---

## Labs

19 hands-on cloud infrastructure labs covering Solutions Architecture, Cloud Engineering, DevOps, SRE, security, and FinOps.

| # | Lab | Role Focus |
|---|-----|-----------|
| 01 | [cloud-migration](./labs/01-cloud-migration) | SA · CE — 6R strategies, workload assessment, TCO |
| 02 | [multi-cloud-architecture](./labs/02-multi-cloud-architecture) | SA — AWS + Azure + GCP cross-cloud design |
| 03 | [terraform-modules](./labs/03-terraform-modules) | CE · DevOps — Reusable IaC module patterns |
| 04 | [iac-terraform-ansible](./labs/04-iac-terraform-ansible) | DevOps · CE — Terraform + Ansible provisioning |
| 05 | [cicd-kubernetes](./labs/05-cicd-kubernetes) | DevOps · SRE — CI/CD pipelines with Kubernetes |
| 06 | [cicd-gitops](./labs/06-cicd-gitops) | DevOps — GitOps workflow with GitHub Actions |
| 07 | [cicd-argocd-rollouts](./labs/07-cicd-argocd-rollouts) | DevOps · SRE — ArgoCD progressive delivery |
| 08 | [kubernetes-observability](./labs/08-kubernetes-observability) | SRE · DevOps — Prometheus + Grafana on K8s |
| 09 | [sre-observability-slo](./labs/09-sre-observability-slo) | SRE — SLOs, SLIs, error budgets |
| 10 | [logging-tracing-pipeline](./labs/10-logging-tracing-pipeline) | SRE · DevOps — ELK Stack + distributed tracing |
| 11 | [incident-response-slo](./labs/11-incident-response-slo) | SRE — SLO-driven incident response |
| 12 | [incident-response-postmortem](./labs/12-incident-response-postmortem) | SRE — Blameless postmortem process |
| 13 | [chaos-engineering-aws](./labs/13-chaos-engineering-aws) | SRE — AWS Fault Injection Simulator |
| 14 | [chaos-engineering-litmus](./labs/14-chaos-engineering-litmus) | SRE — LitmusChaos on Kubernetes |
| 15 | [security-compliance](./labs/15-security-compliance) | SA · CE — IAM, SCPs, GuardDuty, Security Hub |
| 16 | [kubernetes-security](./labs/16-kubernetes-security) | DevOps · SRE — RBAC, Pod Security, network policies |
| 17 | [serverless-data-pipeline](./labs/17-serverless-data-pipeline) | SA · CE — Lambda + S3 + DynamoDB pipeline |
| 18 | [cloud-cost-optimization](./labs/18-cloud-cost-optimization) | SA · CE — FinOps, right-sizing, savings plans |
| 19 | [devops-mastery-ecommerce](./labs/19-devops-mastery-ecommerce) | DevOps — End-to-end DevOps on EKS |

---

## Tech Stack

| Category | Tools |
|---|---|
| **Cloud** | AWS (EC2, VPC, S3, IAM, RDS, Lambda, API Gateway, SQS, SNS, DynamoDB, CloudFront, Route 53, WAF, KMS, CloudWatch, Organizations, EKS, ECR, ECS Fargate, ElastiCache) |
| **IaC** | Terraform · Ansible |
| **Containers** | Docker · Kubernetes · Amazon EKS · Karpenter |
| **CI/CD** | GitHub Actions (OIDC) · ArgoCD · GitOps |
| **Observability** | Prometheus · Grafana · CloudWatch · X-Ray · ELK Stack |
| **Security** | Trivy · GuardDuty · Security Hub · WAF · RBAC · External Secrets |
| **Languages** | Python 3.12 · Bash · Java · SQL |

---

## Certifications and Technical Skills

- **AWS Solutions Architect – Associate (SAA-C03)** — Amazon Web Services, Sep 2025
- **ITIL® 4 Foundation: IT Service Management** — PeopleCert, Jun 2026
- **Linux Essentials Certificate** — Linux Professional Institute, May 2025
- **AWS Solutions Architect – Professional** — In Progress

---

## Contact

| | |
|--|--|
| **LinkedIn** | [linkedin.com/in/vanessajen](https://linkedin.com/in/vanessajen) |
| **Email** | [vanessa9373@gmail.com](mailto:vanessa9373@gmail.com) |
| **Location** | Seattle, WA · Remote-First · Open to Relocation |
