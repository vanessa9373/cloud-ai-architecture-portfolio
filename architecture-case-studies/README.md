# Architecture Case Studies

> **What this is:** Six Solutions Architect design exercises. Each one takes a realistic business
> scenario, works through requirements and trade-offs, and lands on a full architecture backed by
> real Terraform.
>
> **What this isn't:** A record of deployed, production systems. The client names, revenue
> figures, and outage numbers below are illustrative — invented to give each design decision a
> concrete constraint to reason against, the way a real engagement would. Every architecture
> decision, trade-off, and cost model is real analysis; the business context around it is a
> practice scenario, not a client history.

## Scenarios

| Scenario | Focus |
|---|---|
| [E-Commerce Platform](./ecommerce-platform) | Multi-region HA/DR, PCI-DSS, flash-sale traffic spikes |
| [SaaS Platform](./saas-platform) | Multi-tenant serverless, Cognito, per-tenant isolation |
| [Fintech Data Lake](./fintech-data-lake) | S3 data lake, Glue, Athena, PCI data handling |
| [Media Platform](./media-platform) | CloudFront + MediaConvert at global scale |
| [Ridesharing Platform](./ridesharing-platform) | Real-time location data, Cognito, Lambda |
| [PixelVault (Image Processing)](./pixelvault-platform) | Event-driven image pipeline, storage/compute trade-offs |

Each folder contains a `README.md` walking through the scenario and architecture, and a
`terraform/` directory with the infrastructure the design describes.
