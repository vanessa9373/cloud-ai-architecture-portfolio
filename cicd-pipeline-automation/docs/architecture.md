# Architecture

## Pipeline stages (`.github/workflows/deploy.yml`)

| Stage | Job | What it does | Failure behavior |
|---|---|---|---|
| 1 | `test` | `npm ci`, `eslint`, `jest` | Pipeline stops; nothing is built |
| 2 | `build-and-push` | Assumes the OIDC deploy role, builds the Docker image, scans it, pushes `:sha` and `:latest` to ECR | Pipeline stops; no deploy attempted |
| 3 | `deploy-staging` | Captures the current task definition ARN, renders + registers a new one pointing at the just-pushed image, updates the ECS service, waits for steady state, then smoke-tests `/health` through the staging ALB | On smoke test failure: `scripts/rollback.sh` forces the service back to the captured ARN |
| 4 | `deploy-production` | Same as stage 3, gated behind a GitHub Environment (`production`) that requires manual approval | Same rollback behavior, isolated to the production cluster/service |

## Two-layer rollback

- **ECS deployment circuit breaker** (`terraform/modules/ecs/main.tf`): built into the `aws_ecs_service` resource. Catches deployments where new tasks never become healthy at all (crash loop, bad image, failing container health check).
- **Pipeline smoke test + `scripts/rollback.sh`**: catches deployments where tasks *do* start and pass their container health check, but the application itself is broken in a way only an external HTTP request would reveal (e.g. a downstream dependency misconfigured for that environment).

Both target the same rollback mechanism — forcing the ECS service back onto a specific task definition revision — so they're complementary, not duplicated effort.

## Environment isolation

Staging and production are entirely separate stacks (`terraform apply -var-file=environments/<env>.tfvars`): separate VPC, ALB, ECS cluster, and service. A broken staging deploy cannot affect production capacity, and the two environments can run different `desired_count` / task sizes (see `terraform/environments/*.tfvars`).

Account-level resources — the ECR repository and the GitHub OIDC deploy role — are provisioned once from `terraform/global` and shared by both environments, since there is only one artifact registry and one CI identity to manage.

## Why OIDC instead of static AWS keys

`terraform/global/github-oidc.tf` registers GitHub's OIDC provider with IAM and creates a role that only `repo:<org>/cicd-pipeline-automation:*` can assume, scoped to just the ECR push and ECS deploy actions it needs (`terraform/global/github-oidc.tf`, `aws_iam_role_policy.github_deploy`). No AWS access keys are stored as GitHub secrets, so there's nothing long-lived to leak or rotate.
