# Project 5: EKS Online Boutique — Deployment Guide

> **Goal:** Deploy 11 real microservices on Amazon EKS with GitOps (ArgoCD), observability (Prometheus + Grafana), and security (Trivy).
> **Time to complete:** ~90 minutes (EKS cluster creation takes 15-20 min alone)
> **AWS Cost estimate:** ~$0.30-0.40/hour while running. DESTROY WHEN DONE!

---

## Architecture Diagram

```
Developer pushes code
        │
        ▼
┌───────────────────────────────────────────────────┐
│  GitHub Actions CI/CD Pipeline                    │
│  1. Build Docker image                            │
│  2. Trivy security scan (blocks CRITICAL CVEs)    │
│  3. Push image to Amazon ECR                      │
│  4. Update image tag in kubernetes/ manifests     │
└───────────────────────┬───────────────────────────┘
                        │ git push manifest update
                        ▼
┌───────────────────────────────────────────────────┐
│  ArgoCD (GitOps Controller)                       │
│  Watches git repo for manifest changes            │
│  Auto-syncs running cluster to desired state      │
│  Rollback = git revert (no kubectl commands)      │
└───────────────────────┬───────────────────────────┘
                        │ applies manifests
                        ▼
┌───────────────────────────────────────────────────┐
│  Amazon EKS Cluster (Kubernetes 1.28)             │
│  3 AZs | Managed Node Groups | IRSA for AWS API  │
│                                                   │
│  11 Microservices:                                │
│  ┌─────────┐  ┌──────────┐  ┌─────────────────┐  │
│  │Frontend │  │ Cart Svc │  │ Product Catalog  │  │
│  │(Go)     │  │ (Go)     │  │ (Go)            │  │
│  └────┬────┘  └────┬─────┘  └────────┬────────┘  │
│       │            │                  │            │
│  ┌────┴────────────┴──────────────────┴─────────┐ │
│  │     Kubernetes Services (ClusterIP/NLB)       │ │
│  └───────────────────────────────────────────────┘ │
│                                                   │
│  ┌─────────────────────────────────────────────┐  │
│  │  Karpenter (Node Autoscaler)                │  │
│  │  Provisions nodes in <60 seconds            │  │
│  │  Right-sizes per workload (30% cost saving) │  │
│  └─────────────────────────────────────────────┘  │
│                                                   │
│  ┌─────────────────────────────────────────────┐  │
│  │  Observability Stack                        │  │
│  │  Prometheus → Metrics collection            │  │
│  │  Grafana → Dashboards (golden signals)      │  │
│  │  X-Ray → Distributed tracing                │  │
│  └─────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────┘
```

---

## The 11 Microservices

| Service | Language | What it does |
|---------|----------|-------------|
| **frontend** | Go | Web UI served to users |
| **productcatalogservice** | Go | Product listings, search |
| **cartservice** | Go | Shopping cart (Redis backend) |
| **checkoutservice** | Go | Order checkout flow |
| **paymentservice** | Node.js | Payment processing |
| **emailservice** | Python | Order confirmation emails |
| **shippingservice** | Go | Shipping cost calculation |
| **currencyservice** | Node.js | Currency conversion |
| **recommendationservice** | Python | "You might also like..." |
| **adservice** | Java | Ad targeting |
| **loadgenerator** | Python | Synthetic traffic for testing |

---

## What You Will Learn

- How Kubernetes Deployments, Services, and Namespaces work
- How GitOps with ArgoCD works (git = source of truth)
- How Karpenter replaces Cluster Autoscaler (faster, cheaper)
- How Prometheus scrapes metrics and Grafana visualizes them
- How Trivy scans container images for CVEs before deploymen
- How IRSA (IAM Roles for Service Accounts) gives Pods AWS permissions

---

## Prerequisites

```
[ ] AWS CLI configured
[ ] Terraform >= 1.6
[ ] kubectl installed → https://kubernetes.io/docs/tasks/tools/
[ ] helm installed → https://helm.sh/docs/intro/install/
[ ] Docker installed (for building images)
[ ] Git installed
```

**Install kubectl (Mac):**
```bash
brew install kubectl
kubectl version --clien
```

**Install helm (Mac):**
```bash
brew install helm
helm version
```

---

## Step 1: Bootstrap (One-Time)

```bash
cd eks-online-boutique/bootstrap
terraform ini
terraform apply
# Type "yes"
cd ..
```

---

## Step 2: Deploy EKS Infrastructure with Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars if needed (defaults work for learning)

terraform ini
terraform plan   # Shows ~60-80 resources
terraform apply  # Takes 15-20 minutes for EKS cluster
# Type "yes"
```

**What Terraform creates:**
- VPC with 3 public + 3 private subnets across 3 AZs
- EKS cluster (Kubernetes 1.28)
- EKS managed node groups (initial nodes for system components)
- 11 ECR repositories (one per microservice)
- IRSA roles (IAM roles that Pods can assume)
- Karpenter NodePool (for automatic node provisioning)

---

## Step 3: Configure kubectl to Talk to Your Cluster

```bash
# Update your local kubectl config to point to the new EKS cluster
aws eks update-kubeconfig
  --name eks-online-boutique
  --region us-east-1

# Verify kubectl can reach the cluster
kubectl get nodes
# Expected output:
# NAME                          STATUS   ROLES    AGE   VERSION
# ip-10-0-1-100.ec2.internal   Ready    <none>   5m    v1.28.x
```

---

## Step 4: Install ArgoCD

ArgoCD is the GitOps controller — it watches your git repo and keeps the cluster in sync.

```bash
# Create ArgoCD namespace (a namespace is like a folder in Kubernetes)
kubectl create namespace argocd

# Install ArgoCD using its official manifes
kubectl apply -n argocd
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available deployment/argocd-server
  -n argocd --timeout=300s

# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secre
  -o jsonpath="{.data.password}" | base64 -d
# COPY THIS PASSWORD — you'll need it in Step 5
```

---

## Step 5: Access the ArgoCD UI

```bash
# Port-forward ArgoCD to your local machine
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Open in your browser: https://localhost:8080
# Username: admin
# Password: (the password you copied in Step 4)
```

---

## Step 6: Deploy the Microservices via ArgoCD

```bash
# Apply the ArgoCD Application manifes
# This tells ArgoCD: "watch this git repo and deploy kubernetes/ folder to the cluster"
kubectl apply -f argocd/application.yaml

# ArgoCD will now:
# 1. Clone your git repo
# 2. Find all YAML files in kubernetes/
# 3. Apply them to the cluster
# 4. Keep the cluster in sync with git going forward
```

**Watch the deployment in the ArgoCD UI:**
- You'll see 11 microservices appear
- Each will show "Syncing" → "Healthy"

---

## Step 7: Access the Online Boutique Frontend

```bash
# Get the external IP of the frontend LoadBalancer
kubectl get service frontend-external -n online-boutique

# Expected output:
# NAME                TYPE           CLUSTER-IP   EXTERNAL-IP      PORT(S)
# frontend-external   LoadBalancer   10.0.0.100   1.2.3.4         80:31234/TCP
```

Open http://EXTERNAL-IP in your browser — you should see the Online Boutique shopping site!

---

## Step 8: Install Prometheus + Grafana (Observability)

```bash
# Add the Helm chart repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus + Grafana (kube-prometheus-stack includes both)
helm install monitoring prometheus-community/kube-prometheus-stack
  --namespace monitoring
  --create-namespace
  --set grafana.adminPassword=admin123

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana
  -n monitoring --timeout=300s

# Access Grafana
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80 &
# Open: http://localhost:3000 | Username: admin | Password: admin123
```

**Golden Signals Dashboards to check:**
1. Search for "Kubernetes / Workloads / Namespace" → see CPU/memory per microservice
2. Search for "Node Exporter Full" → see node-level metrics

---

## Step 9: Understand IRSA (IAM Roles for Service Accounts)

IRSA lets Kubernetes Pods call AWS services without credentials stored in the Pod.

**How it works:**
1. Terraform creates an IAM role with a specific trust policy
2. The trust policy says: "Pods in namespace X with service account Y can assume this role"
3. The Pod's service account is annotated with the role ARN
4. AWS SDK in the Pod automatically gets temporary credentials

**Example:** The cartservice needs to read from ElastiCache (an AWS service):
```yaml
apiVersion: v1
kind: ServiceAccoun
metadata:
  name: cartservice
  namespace: online-boutique
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT:role/cartservice-irsa-role"
```
No password, no access key stored anywhere.

---

## Step 10: Test the GitOps Flow

1. Edit a Kubernetes manifest (e.g., change a replica count)
2. Commit and push to your fork
3. Watch ArgoCD detect the change and apply it automatically
4. You did NOT run `kubectl apply` manually — git is the source of truth

```bash
# Edit kubernetes/services/cartservice.yaml
# Change replicas from 1 to 2

# Commit and push
git add kubernetes/services/cartservice.yaml
git commit -m "Scale cartservice to 2 replicas"
git push

# Watch ArgoCD sync (in the UI or CLI)
kubectl get pods -n online-boutique -w
# You'll see a new cartservice pod appear automatically
```

---

## Step 11: Test Karpenter Auto-Scaling

```bash
# Create a test deployment that needs more capacity
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deploymen
metadata:
  name: inflate
spec:
  replicas: 5
  selector:
    matchLabels:
      app: inflate
  template:
    metadata:
      labels:
        app: inflate
    spec:
      containers:
      - name: inflate
        image: public.ecr.aws/eks-distro/kubernetes/pause:3.7
        resources:
          requests:
            cpu: "1"
EOF

# Watch Karpenter provision a new node (takes <60 seconds!)
kubectl get nodes -w
# You'll see a new node appear within 60 seconds

# Clean up
kubectl delete deployment inflate
# Karpenter removes the unused node automatically
```

---

## Step 12: DESTROY When Done

```bash
# 1. Delete Kubernetes resources firs
kubectl delete -f argocd/application.yaml
helm uninstall monitoring -n monitoring
kubectl delete namespace argocd online-boutique monitoring

# 2. Destroy AWS infrastructure
cd terraform
terraform destroy
# Type "yes"
# Takes 15-20 minutes
```

---

## What to Say in an Interview

> "I deployed the Google Online Boutique — 11 real microservices across Go, Python, Java, C-sharp, and Node.js — on Amazon EKS with Terraform provisioning the cluster, VPC, ECR repositories, and IRSA roles. My CI/CD pipeline uses GitHub Actions with OIDC authentication: on every commit it builds the Docker image, runs Trivy to block any CRITICAL CVEs, pushes to ECR, and updates the image tag in the Kubernetes manifest. ArgoCD detects the manifest change and automatically syncs the cluster — this is GitOps: git is the source of truth, rollback is just a git revert. I used Karpenter instead of Cluster Autoscaler because Karpenter provisions nodes in under 60 seconds and right-sizes instance types per workload, achieving approximately 30% cost reduction versus static node groups. Observability runs Prometheus plus Grafana monitoring the four golden signals across all 11 services."
