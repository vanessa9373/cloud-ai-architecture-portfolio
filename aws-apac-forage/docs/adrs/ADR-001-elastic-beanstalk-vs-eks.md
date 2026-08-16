# ADR-001: Elastic Beanstalk vs EKS for ShopLocal

**Date:** 2025-09
**Status:** Accepted
**Author:** Vanessa Awo, Solutions Architect

## Context

ShopLocal runs a PHP/WordPress application. They have 1 developer with no container or Kubernetes experience. They need compute that auto-scales, handles deployments, and doesn't require infrastructure expertise to operate.

## Options Considered

### Option A: Amazon EKS (Elastic Kubernetes Service)
- Pros: Industry standard, highly flexible, best for microservices, strong ecosystem
- Cons: Requires Kubernetes expertise (hiring cost: ~$180K/year DevOps engineer). kubectl, Helm charts, RBAC, pod scheduling — steep learning curve. Overkill for a monolithic WordPress app.

### Option B: AWS Elastic Beanstalk
- Pros: Managed platform — AWS handles Auto Scaling, load balancing, health monitoring. Developers deploy by `git push` or zip upload. No infrastructure expertise required. Supports PHP natively.
- Cons: Less control than EKS. Not suitable for microservices at scale. Harder to customize at the infrastructure layer.

### Option C: EC2 Auto Scaling Group + ALB (Manual)
- Pros: Full control, industry standard for stateless apps
- Cons: Requires manual launch template configuration, ASG policies, target group management. More expertise needed than Elastic Beanstalk.

## Decision

**Elastic Beanstalk.**

Right-sized for the client's current operational maturity. The client can deploy without changing their workflow. AWS manages the scaling, health replacement, and load balancing.

## Consequences

- ShopLocal does not need to hire DevOps expertise
- Deployment is simplified (developer focus stays on the product)
- Less flexibility for custom Kubernetes patterns
- If ShopLocal grows to microservices or hires DevOps, this decision should be revisited

## Revisit Trigger

- Client hires a dedicated DevOps or platform engineering team
- Traffic grows beyond 10,000 concurrent users (Beanstalk scaling limits become relevant)
- Client wants to adopt microservices architecture
