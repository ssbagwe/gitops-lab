# GitOps Lab

A self-contained dev container for practicing Kubernetes, ArgoCD, Crossplane, Terraform, and AWS (via LocalStack).

## Table of Contents

- [Quick Start](#quick-start)
- [Included Tools](#included-tools)
- [Common Commands](#common-commands)
  - [Git](#git-via-oh-my-zsh-git-plugin)
  - [Kubernetes](#kubernetes)
  - [Krew Plugins](#krew-plugins)
  - [ArgoCD](#argocd)
  - [LocalStack (AWS)](#localstack-aws)
  - [Terraform](#terraform)
  - [Lab Management](#lab-management)
  - [Watch Resources](#watch-resources)
- [Practice Scenarios](#practice-scenarios)
- [Troubleshooting](#troubleshooting)
- [Resource Usage](#resource-usage)

## Quick Start

1. **Open in VS Code**

   ```bash
   code gitops-lab
   ```

   Then use Command Palette → "Dev Containers: Reopen in Container". This will build the DevContainer Image and start the DevContainer.

2. **Start the lab**

   Open New Terminal in VS Code.
   ```bash
   lab-up
   ```

   This creates:
   - 3-node kind cluster (1 control plane, 2 workers)
   - ArgoCD for GitOps
   - LocalStack for AWS services

3. **Check status**

   ```bash
   lab-status
   argo-ui
   ```

## Included Tools

| Tool | Version | Purpose |
|------|---------|---------|
| kubectl | 1.34.2 | K8s CLI |
| helm | 4.0.4 | Package manager |
| kind | 0.31.0 | Local K8s clusters |
| k9s | 0.50.18 | Terminal UI |
| terraform | 1.14.3 | Infrastructure as Code |
| argocd | 3.2.6 | GitOps CD |
| kustomize | 5.6.0 | K8s config management |
| krew | 0.4.4 | kubectl plugin manager |
| awscli | v2 | AWS CLI |
| go | 1.23.5 | For operators/tools |

### Krew Plugins (pre-installed)

| Plugin | Purpose |
|--------|---------|
| ctx | Context switching (like kubectx) |
| ns | Namespace switching (like kubens) |
| neat | Clean up verbose YAML output |
| tree | Show resource ownership hierarchy |
| images | List container images in cluster |
| node-shell | SSH into nodes |
| resource-capacity | Show node resource allocation |

## Common Commands

### Git (via oh-my-zsh git plugin)

```bash
gst                    # git status
gsw branch-name        # git switch
ga / gaa               # git add / add all
gcmsg "message"        # git commit -m
gp / gl                # git push / pull
gpsup                  # git push --set-upstream origin $(git_current_branch)
gcb feature-x          # git checkout -b
gd / gds               # git diff / diff staged
glog                   # pretty git log
grbi HEAD~3            # git rebase -i
gsta / gstp            # git stash / stash pop
```

Full list: <https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/git>

### Kubernetes

```bash
k9s                    # Terminal UI
kgp                    # kubectl get pods
kga                    # kubectl get all
kaf <file>             # kubectl apply -f
stern <pod>            # Log tailing
```

### Krew Plugins

```bash
kubectl ctx            # Switch context (like kubectx)
kubectl ns             # Switch namespace (like kubens)
kubectl neat get pod x # Clean yaml output
kubectl tree deploy x  # Show resource hierarchy
kubectl images         # List all images in cluster
kubectl resource-capacity  # Node resource allocation
```

### ArgoCD

```bash
argo-ui                # Port-forward + show creds
argo-pass              # Get admin password
argocd app list        # List applications
argocd app sync <app>  # Sync an app
```

### LocalStack (AWS)

```bash
laws s3 ls                           # List S3 buckets
laws s3 mb s3://my-bucket            # Create bucket
laws dynamodb list-tables            # List DynamoDB tables
test-s3                              # Quick S3 smoke test
localstack-status                    # Health check
```

### Terraform

```bash
cd terraform/
tf init                # Initialize
tf plan                # Preview changes
tf apply               # Apply changes
```

### Lab Management

```bash
lab-up                 # Start everything
lab-down               # Tear down
lab-reset              # Full reset
lab-status             # Check status
```

### Watch resources

```bash
kubectl get managed -w
```

## Practice Scenarios

### 1. GitOps with ArgoCD

```bash
# Deploy sample app via ArgoCD
kubectl apply -f argocd-apps/sample-app.yaml

# Watch it sync
argocd app get sample-app --watch
```

### 2. Terraform + LocalStack

```bash
cd terraform/
cat > s3.tf << 'EOF'
resource "aws_s3_bucket" "logs" {
  bucket = "my-app-logs"
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}
EOF

tf init && tf apply
```

### 3. Helm Chart Development

```bash
cd helm-charts/
helm create my-app
helm install my-app ./my-app --dry-run
helm install my-app ./my-app
```

## Troubleshooting

**Docker not starting?**

- **Linux**: Ensure Docker service is running (`sudo systemctl start docker`) and your user is in the docker group (`sudo usermod -aG docker $USER`, then log out and back in)
- **Mac**: Make sure Docker Desktop or OrbStack is running
- **Windows**: Make sure Docker Desktop is running and WSL2 is enabled

**Kind cluster won't create?**

- Check Docker has enough resources (8GB+ RAM recommended)
- Try `lab-reset`

**ArgoCD pods not ready?**

- Wait a bit longer, or check: `kubectl get pods -n argocd`
- Check events: `kubectl get events -n argocd --sort-by='.lastTimestamp'`

**LocalStack not responding?**

- Check logs: `docker logs localstack`
- Restart: `docker restart localstack`

## Resource Usage

Approximate memory usage when fully running:

- Kind cluster (3 nodes): ~3-4GB
- LocalStack: ~1GB
- Dev container overhead: ~500MB
- **Total: ~5-6GB RAM**
