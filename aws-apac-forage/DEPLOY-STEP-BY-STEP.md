# Project 6: AWS APAC Solutions Architecture Simulation — Guide

> **What this is:** A full SA/SE engagement simulation — discovery → architecture → stakeholder communication → objection handling. Certified by AWS × Forage.
> **This project is different:** It's about demonstrating the SA thought process, not just deploying infrastructure.

---

## The Client Scenario

A small Australian e-commerce company ("ShopLocal") runs their entire business on a SINGLE EC2 instance. No redundancy. No backups. They've had 2 outages in 6 months — each costing ~$5,000 in lost sales.

**Current architecture (the problem):**
```
Internet → Single EC2 Instance (web + app + database all in one)
           └── If this fails → entire business is down
```

**Your job as the SA:** Discover their pain, design a better architecture, communicate it clearly, and handle the "it costs more!" objection.

---

## Phase 1: Discovery (Technical Pre-Sales)

Before designing anything, an SA asks questions to understand:

### Discovery Script — Ask These Questions

```
Business questions:
- How many concurrent users do you have at peak?
- What's your current monthly revenue? (helps quantify downtime cost)
- What's the cost to your business of 1 hour of downtime?
- Do you have any compliance requirements? (data residency, PCI-DSS, etc.)

Technical questions:
- What OS and web framework are you using?
- Do you use a database? What type?
- What's your current backup strategy?
- Do you have a staging/test environment?
- What's your deployment process today?

Pain points:
- Tell me about the outages you've had. What caused them?
- What keeps you up at night about your infrastructure?
- What does your team look like? Do you have a dedicated DevOps person?
```

### What I Discovered

| Question | Answer |
|----------|--------|
| Peak concurrent users | ~500 |
| Revenue | ~$50,000/month |
| Cost of 1 hour downtime | ~$2,500 |
| Outages last 6 months | 2 outages × ~2 hours each = ~$10,000 lost |
| Stack | PHP/WordPress + MySQL |
| Backups | Manual snapshots, weekly |
| Team | 1 developer, not DevOps-focused |
| Pain | "We can't afford downtime during our Black Friday sale" |

### Single Points of Failure I Identified

1. **Single EC2 instance** — one hardware failure = full outage
2. **No load balancer** — can't distribute traffic or survive instance failure
3. **Database on same instance as web** — DB crash = app crash
4. **No Auto Scaling** — Black Friday traffic spike = overloaded single server
5. **Manual weekly backups** — up to 7 days of data could be los
6. **No CDN** — all traffic hits the server, including static files

---

## Phase 2: Architecture Design

### The Recommendation

```
BEFORE:                              AFTER:
Internet                             Interne
   │                                    │
   ▼                                    ▼
Single EC2                        CloudFront CDN
(web+db+all)                      (PriceClass_200: US, Europe, Asia)
                                        │
                                        ▼
                                  Route 53 (DNS failover)
                                        │
                                        ▼
                                  Elastic Beanstalk
                                  (manages EC2 Auto Scaling, ALB automatically)
                                  Multi-AZ deploymen
                                        │
                                        ▼
                                  RDS MySQL Multi-AZ
                                  (Primary + Standby, auto-failover <2 min)
                                  Daily automated backups (35-day retention)
```

### Why Elastic Beanstalk Instead of EKS?

**ADR-001:** Elastic Beanstalk vs EKS for ShopLocal

- **EKS** would give more control and flexibility, but requires Kubernetes expertise the client doesn't have. Hiring a Kubernetes engineer would add ~$180K/year in salary.
- **Elastic Beanstalk** handles EC2 Auto Scaling, load balancing, and health monitoring automatically. The client's single PHP developer can deploy by pushing code — no Kubernetes knowledge needed.
- **Decision:** Elastic Beanstalk. Right-sized for this client's operational capability.
- **Revisit if:** Client hires DevOps engineering team or traffic grows 10x.

### Why CloudFront PriceClass_200?

ShopLocal sells to Australia, US, and Europe. PriceClass_200 covers these regions at lower cost than All (which includes South America and Africa where they have no customers). Cost saving: ~20% vs PriceClass_All.

---

## Phase 3: Stakeholder Communication

### Explaining Auto Scaling (Non-Technical Client)

> "Right now, your restaurant has one waiter. When 50 customers walk in for Black Friday, that one waiter can't handle everyone. Some customers give up and leave — that's lost sales.
>
> Elastic Beanstalk with Auto Scaling is like having a contract with a staffing agency. When 50 customers show up, 5 waiters appear within minutes. When the rush ends, they go home. You only pay for the extra staff during the busy hours.
>
> Your developer doesn't manage the waiters — the staffing agency (AWS) handles that automatically."

### Explaining Multi-AZ RDS (Non-Technical Client)

> "Right now your database is on the same computer as your website. If that computer has a hardware problem, everything stops.
>
> Multi-AZ is like having two cash registers in your shop, in different buildings. Both show the same balance at all times. If one building catches fire, the other one automatically takes over in under two minutes. Your customers never notice."

---

## Phase 4: Handling Objections

### Objection: "This is 4x more expensive! You want me to pay $280/month instead of $70?"

**Wrong response:** "Yes, but it's more reliable."

**Correct SA response:**

> "You're right that the monthly cost goes from $70 to $280 — an increase of $210.
>
> Let's look at what you're currently paying for your current setup:
> - 2 outages in 6 months × ~2 hours each × ~$2,500/hour = **$10,000 in lost revenue**
> - That's $10,000 over 6 months = **$1,667/month in hidden costs**
>
> The new architecture eliminates the single point of failure that caused both outages. You're not paying $210 more per month. You're **saving $1,457 per month** ($1,667 risk eliminated - $210 increase).
>
> Put another way: your current $70/month solution is actually costing you $1,737/month when you factor in downtime. This $280 solution is 84% cheaper in total cost of ownership."

**This is the key SA skill:** Reframing cost as risk transfer, not overhead.

---

## Phase 5: Deploy the Architecture

```bash
# Bootstrap firs
cd aws-apac-forage/bootstrap
terraform init && terraform apply

# Configure variables
cd ..
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit: set your domain name, db password, alert email

# Deploy
cd terraform
terraform ini
terraform plan
terraform apply
# Takes ~15-20 minutes (RDS is slowest)
```

---

## Phase 6: Architecture Decision Records

See `docs/adrs/` folder for all ADRs:
- `ADR-001-elastic-beanstalk-vs-eks.md`
- `ADR-002-cloudfront-price-class.md`
- `ADR-003-rds-multi-az-vs-single.md`
- `ADR-004-route53-health-checks.md`

---

## DESTROY When Done

```bash
cd terraform
terraform destroy
```

---

## What to Say in an Interview

> "The AWS APAC Forage simulation had me perform the full solutions architect pre-sales motion: discovery, architecture design, stakeholder communication, and objection handling. I identified six single points of failure on the client's single-EC2 setup. I recommended Elastic Beanstalk over EKS because the client had one PHP developer with no Kubernetes experience — EKS would have been technically superior but operationally unsustainable for them. I documented this as an ADR: right tool for the client's operational maturity, with an explicit trigger to revisit if they scale. The key moment was handling the cost objection: the client saw a 4x increase from $70 to $280 per month. I reframed it as total cost of ownership — their current setup was costing $1,667 per month in hidden downtime costs. The new architecture was actually 84% cheaper in TCO."
