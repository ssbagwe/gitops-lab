# GitOps Lab

A self-contained dev container for practicing Kubernetes, ArgoCD, Crossplane, Terraform, and AWS (via LocalStack).

## Table of Contents

- [Prerequisites](#prerequisites)
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

## Prerequisites

### Install Docker

#### Linux (Ubuntu/Debian)

```bash
# Update package index
sudo apt-get update

# Install dependencies
sudo apt-get install -y ca-certificates curl gnupg

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add your user to the docker group (log out and back in after this)
sudo usermod -aG docker $USER
```

#### Mac

Install [Docker Desktop for Mac](https://docs.docker.com/desktop/setup/install/mac-install/) or use Homebrew:

```bash
brew install --cask docker
```

Then launch Docker Desktop from Applications and wait for it to start.

### Clone the gitops-lab Repository

```bash
# Install Microsoft Visual Studio Code & git
git clone https://github.com/ssbagwe/gitops-lab.git
```

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
   ```

4. **Deploy the platform & lab applications, port forward ArgoCD UI and generate Admin Login creds**

   ```bash
   kubectl apply -n argocd -f /workspaces/gitops-lab/argocd-apps/deploy/repo-links.yaml

   argo-ui
   ```

   <em style="color: green;">Wait for the Applications to deploy and turn green. It will take a while depending on your compute and network.</em>


## Included Tools

| Tool | Version | Purpose |
|------|---------|---------|
| argocd | 3.3.0 | GitOps CD |
| awscli | v2 | AWS CLI |
| go | 1.23.5 | For operators/tools |
| helm | 4.1.0 | Package manager |
| k9s | 0.50.18 | Terminal UI |
| kind | 0.31.0 | Local K8s clusters |
| krew | 0.4.5 | kubectl plugin manager |
| kubectl | 1.34.4 | K8s CLI |
| kustomize | 5.6.0 | K8s config management |
| stern | 1.31.0 | Log tailing |
| terraform | 1.14.3 | Infrastructure as Code |

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

**Promtail failing with "Too many open files" error ?**

- **Linux Docker Host**:

   ```bash
   echo "fs.inotify.max_user_watches=1048576" | sudo tee -a /etc/sysctl.d/99-sysctl.conf
   echo "fs.inotify.max_user_instances=8192" | sudo tee -a /etc/sysctl.d/99-sysctl.conf
   sudo sysctl --system
   ```

## Resource Usage

Approximate resource usage when fully running:

| Component | CPU (cores) | Memory | Notes |
|-----------|-------------|--------|-------|
| Kind control-plane | ~380m | ~1.3 GB | API server, etcd, scheduler, controller-manager |
| Kind worker (x2) | ~470m | ~2.6 GB | Workload nodes (~0.8-1.8 GB each) |
| Monitoring stack | ~230m | ~1.1 GB | Prometheus, Grafana, Loki, Promtail |
| ArgoCD | ~53m | ~550 MB | All ArgoCD components |
| LocalStack | ~50m | ~100 MB | AWS service emulation |
| Dev container overhead | — | ~500 MB | |
| **Total** | **~1.2 cores** | **~6 GB RAM** | **4+ CPU cores, 8 GB+ RAM recommended** |

### How to check resource usage

```bash
# Docker container stats (CPU + memory per container)
docker stats --no-stream

# Kubernetes node-level usage (requires metrics-server)
kubectl top nodes

# Kubernetes pod-level usage
kubectl top pods -A

# Node resource requests/limits summary (krew plugin)
kubectl resource-capacity
```
