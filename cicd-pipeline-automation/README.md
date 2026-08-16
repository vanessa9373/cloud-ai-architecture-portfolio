# CI/CD Pipeline Automation

[![CI](https://github.com/vanessa9373/cicd-pipeline-automation/actions/workflows/ci.yml/badge.svg)](https://github.com/vanessa9373/cicd-pipeline-automation/actions/workflows/ci.yml)

An end-to-end CI/CD pipeline that builds, tests, containerizes, and deploys a small Node.js API to **AWS ECS Fargate** using **GitHub Actions**, with automatic rollback on a failed deployment.

> **Status:** infrastructure-as-code and pipeline are complete and validated (`terraform validate`, `terraform fmt`, full test suite passing), but **not deployed** — no AWS resources are currently running, so there's no ongoing cost. See [Deploying it yourself](#deploying-it-yourself) to stand it up in your own account.

---

## Architecture Overview

```
GitHub push to main
        │
        ▼
┌────────────────────┐
│  1. Test            │  npm ci → eslint → jest (unit tests + coverage)
└────────────────────┘
        │
        ▼
┌────────────────────┐
│  2. Build & Push    │  docker build → Trivy scan → push to Amazon ECR
└────────────────────┘
        │
        ▼
┌────────────────────┐
│  3. Deploy: Staging │  render task def → ecs update-service → wait for
└────────────────────┘  steady state → smoke test /health via ALB
        │                       │
        │                  fails │ passes
        │                       ▼
        │              ┌──────────────────┐
        │              │ auto rollback to  │
        │              │ previous task def │
        │              └──────────────────┘
        ▼
┌────────────────────┐
│  4. Deploy: Prod    │  manual approval gate (GitHub Environment)
└────────────────────┘  → same deploy → smoke test → rollback-on-failure
```

```
                        Internet
                            │
                 ┌──────────────────┐
                 │  Application LB   │  :80 → target group health check /health
                 └──────────────────┘
                            │
              ┌─────────────┴─────────────┐
              │      VPC (2 AZs)           │
              │  Public subnets: ALB, NAT  │
              │  Private subnets:          │
              │    ECS Fargate tasks       │◄── pulls image from ECR
              │    (widget-inventory-api)  │
              └────────────────────────────┘
```

Each environment (staging, production) gets its own VPC, ALB, ECS cluster and service — deployed independently so a bad staging rollout can never touch production. The ECR repository and the GitHub OIDC deploy role are account-level and shared across both.

---

## Why ECS Fargate + a deployment circuit breaker

Rollback is implemented at two layers, deliberately redundant:

1. **Infrastructure-level (`terraform/modules/ecs`):** the ECS service has `deployment_circuit_breaker { enable = true, rollback = true }`. If new tasks fail to reach a healthy steady state, ECS itself aborts the rollout and redeploys the last known-good task definition — no pipeline code involved.
2. **Pipeline-level (`scripts/rollback.sh`):** after ECS reports a stable deployment, the workflow still runs an application-level smoke test against `/health` through the ALB. If *that* fails — a case the circuit breaker alone wouldn't catch, e.g. the app boots but a downstream dependency is broken — the workflow captures the previous task definition ARN before deploying and forces the service back onto it.

---

## Technology Stack

| Category            | Tool                              | Purpose                                   |
|----------------------|------------------------------------|--------------------------------------------|
| Application          | Node.js 20 / Express               | Small REST API (`/health`, `/widgets`)     |
| Containerization      | Docker (multi-stage build)         | Identical image across dev/staging/prod    |
| CI/CD                 | GitHub Actions                     | Build → test → deploy automation           |
| Container Registry    | Amazon ECR                         | Image storage, scan-on-push                |
| Compute               | AWS ECS on Fargate                 | Serverless container hosting               |
| Load Balancing        | Application Load Balancer          | Health-checked traffic routing             |
| IaC                   | Terraform (modular)                | Reproducible per-environment infra         |
| Auth                  | GitHub OIDC → IAM role             | No long-lived AWS keys in GitHub secrets   |
| Security Scanning     | Trivy                              | Filesystem + image vulnerability scanning  |
| Testing               | Jest + Supertest                   | Unit/integration tests, run in CI and again inside the Docker build |

---

## Repository Structure

```
cicd-pipeline-automation/
├── .github/workflows/
│   ├── ci.yml               # PR checks: lint, test, docker build, terraform validate
│   └── deploy.yml           # push-to-main pipeline: test → build/push → deploy → smoke test → rollback
├── app/                     # Node.js/Express API
│   ├── src/
│   ├── tests/
│   └── Dockerfile           # multi-stage build; tests run inside the build stage
├── env/                     # per-environment runtime config (non-secret)
├── docker-compose.yml       # local dev: docker compose up
├── scripts/
│   ├── smoke-test.sh        # polls /health after a deploy
│   └── rollback.sh          # forces a service back onto a prior task definition
├── terraform/
│   ├── global/               # account-level: ECR repo, GitHub OIDC + deploy role (apply once)
│   ├── modules/{vpc,ecr,alb,ecs}/
│   ├── environments/{staging,production}.tfvars
│   └── main.tf               # per-environment: VPC, ALB, ECS (apply per env)
└── docs/
    └── architecture.md
```

---

## Running it locally

```bash
cd app
npm ci
npm test          # jest + supertest
npm run lint

# or via Docker
cd ..
APP_ENV=development docker compose up --build
curl http://localhost:3000/health
```

---

## Deploying it yourself

This provisions real AWS resources and will incur cost (ALB, NAT Gateway, Fargate tasks — all billed hourly).

```bash
# 1. One-time account-level resources: ECR repo + GitHub OIDC deploy role
cd terraform/global
terraform init
terraform apply -var="github_org=<your-gh-org>" -var="github_repo=cicd-pipeline-automation"
# copy the `github_deploy_role_arn` output into the repo's
# AWS_DEPLOY_ROLE_ARN secret (Settings → Secrets and variables → Actions)

# 2. Per-environment infrastructure
cd ../
terraform init
terraform apply -var-file=environments/staging.tfvars
terraform apply -var-file=environments/production.tfvars

# 3. Set the ALB health-check URLs the pipeline smoke-tests against
#    as repository/environment variables:
#      STAGING_HEALTH_URL    = http://<staging alb_dns_name>/health
#      PRODUCTION_HEALTH_URL = http://<production alb_dns_name>/health

# 4. Push to main — GitHub Actions takes it from there.
```

To tear down: `terraform destroy -var-file=environments/<env>.tfvars` per environment, then `terraform destroy` in `terraform/global`.

---

## Testing the rollback path

To see the rollback trigger fire without waiting for a real bug: deploy a build where `/health` intentionally returns a non-200 status, push to `main`, and watch the **Deploy to Staging** job in Actions — the smoke test will fail after its retry budget and `scripts/rollback.sh` will force the service back onto the previous task definition revision.
