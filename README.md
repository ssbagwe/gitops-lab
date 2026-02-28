# GitOps Lab

A self-contained dev container for practicing Kubernetes, ArgoCD, Crossplane, Terraform, and AWS (via LocalStack).

## Table of Contents

- [GitOps Lab](#gitops-lab)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
    - [Install Docker](#install-docker)
      - [Linux (Ubuntu/Debian)](#linux-ubuntudebian)
      - [Mac](#mac)
      - [Windows](#windows)
    - [Install VS Code and Dev Containers Extension](#install-vs-code-and-dev-containers-extension)
    - [Install Technitium DNS server for private DNS zone "lab.internal"](#install-technitium-dns-server-for-private-dns-zone-labinternal)
    - [Configure DNS forwarding to Technitium for `lab.internal`](#configure-dns-forwarding-to-technitium-for-labinternal)
      - [macOS](#macos)
      - [Linux (systemd-resolved)](#linux-systemd-resolved)
      - [Windows (PowerShell)](#windows-powershell)
    - [Clone the gitops-lab Repository](#clone-the-gitops-lab-repository)
  - [Quick Start](#quick-start)
  - [Included Tools](#included-tools)
    - [Krew Plugins (pre-installed)](#krew-plugins-pre-installed)
  - [Common Commands](#common-commands)
    - [Git (via oh-my-zsh git plugin)](#git-via-oh-my-zsh-git-plugin)
    - [Kubernetes](#kubernetes)
    - [Krew Plugins](#krew-plugins)
    - [ArgoCD](#argocd)
    - [LocalStack (AWS)](#localstack-aws)
    - [Terraform](#terraform)
    - [Lab Management](#lab-management)
    - [Watch resources](#watch-resources)
  - [Practice Scenarios](#practice-scenarios)
    - [1. GitOps with ArgoCD](#1-gitops-with-argocd)
    - [2. Terraform + LocalStack](#2-terraform--localstack)
    - [3. Helm Chart Development](#3-helm-chart-development)
  - [Troubleshooting](#troubleshooting)
  - [Resource Usage](#resource-usage)
    - [How to check resource usage](#how-to-check-resource-usage)

## Prerequisites

### Install Docker

#### Linux (Ubuntu/Debian)

```bash
# Configure custom tuning
echo "fs.inotify.max_user_watches=1048576" | sudo tee -a /etc/sysctl.d/99-sysctl.conf
echo "fs.inotify.max_user_instances=8192" | sudo tee -a /etc/sysctl.d/99-sysctl.conf
sudo sysctl --system

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

#### Windows

1. **Install WSL2** (if not already installed) — open PowerShell as Administrator:

   ```powershell
   wsl --install
   ```

   Restart your machine when prompted, then verify:

   ```powershell
   wsl --status
   ```

   Ensure the default version is WSL 2. If not:

   ```powershell
   wsl --set-default-version 2
   ```

2. **Install Docker Desktop** — download from [Docker Desktop for Windows](https://docs.docker.com/desktop/setup/install/windows-install/) or use `winget`:

   ```powershell
   winget install Docker.DockerDesktop
   ```

   During setup, ensure **"Use WSL 2 based engine"** is checked (Settings > General).

3. **Install Git for Windows** (provides `bash` needed by the devcontainer init script):

   ```powershell
   winget install Git.Git
   ```

### Install VS Code and Dev Containers Extension

1. Install [Visual Studio Code](https://code.visualstudio.com/) if not already installed.

2. Install the **Dev Containers** extension:
   - Open VS Code
   - Press `Ctrl+Shift+X` (or `Cmd+Shift+X` on Mac) to open Extensions
   - Search for **Dev Containers** (by Microsoft)
   - Click **Install**

   Or install from the command line:

   ```bash
   code --install-extension ms-vscode-remote.remote-containers
   ```

### Install Technitium DNS server for private DNS zone "lab.internal"

- [Technitium DNS Server - Installation](https://github.com/TechnitiumSoftware/DnsServer?tab=readme-ov-file#installation)
- Create a `lab.internal` DNS zone with `grafana.lab.internal` , `traefik.lab.internal` and `infisical.lab.internal` records pointing to the Docker host's IP address

### Configure DNS forwarding to Technitium for `lab.internal`

Configure your local DNS resolver to forward `lab.internal` queries to the Technitium DNS server:

#### macOS

```bash
sudo mkdir -p /etc/resolver
echo "nameserver <TECHNITIUM_IP>" | sudo tee /etc/resolver/lab.internal
```

Verify with: `scutil --dns | grep lab.internal -A 5`

#### Linux (systemd-resolved)

```bash
sudo mkdir -p /etc/systemd/resolved.conf.d
cat <<EOF | sudo tee /etc/systemd/resolved.conf.d/lab-internal.conf
[Resolve]
DNS=<TECHNITIUM_IP>
Domains=~lab.internal
EOF
sudo systemctl restart systemd-resolved
```

Verify with: `resolvectl query grafana.lab.internal`

#### Windows (PowerShell)

Use PowerShell (as Administrator):

```powershell
Add-DnsClientNrptRule -Namespace ".lab.internal" -NameServers "<TECHNITIUM_IP>"
```

Verify with: `Resolve-DnsName grafana.lab.internal`

> Replace `<TECHNITIUM_IP>` with the IP address of your Technitium DNS server.

### Clone the gitops-lab Repository

```bash
# Install Microsoft Visual Studio Code, git. Also, setup SSH key in github account.
git clone git@github.com:ssbagwe/gitops-lab.git
```

## Quick Start

1. **Open in VS Code**

   ```bash
   ssh-add </path/to/your/private_key_github>
   code gitops-lab
   ```

   Then use Command Palette → "Dev Containers: Reopen in Container". This will build the DevContainer Image and start the DevContainer.

2. **Start the lab**

   Open New Terminal in VS Code.

   ```bash
   lab-up # or lab-reset after rebuilds
   ```

   Open New Terminal in VS Code to check the status of ArgoCD pods

   ```bash
   k9s -n argocd
   ```

   This creates:
   - 3-node kind cluster (1 control plane, 2 workers)
   - ArgoCD for GitOps
   - CoreDNS patching for `lab.internal` DNS forwarding (prompts for Technitium DNS IP)
   - Deploys platform & lab ArgoCD applications
   - LocalStack for AWS services

3. **Login to ArgoCD UI**

   ```bash
   argo-ui
   ```

   > [!IMPORTANT]
   > Login to ArgoCD UI and Wait for the Applications to deploy and turn green. It will take a while depending on your compute and network.
   > Ignore External Secrets and Infisical because it requires additional configuration at `Step 6` below.

4. **Import the Step CA root certificate for browser trust**

   Export the current root CA from the cluster:

   ```bash
   kubectl get configmap -n traefik step-ca-step-certificates-certs \
     -o jsonpath='{.data.root_ca\.crt}'
   ```

   > **Note:** Each `lab-reset` or devcontainer rebuild generates a new root CA. Remove old ones before importing to avoid stale certificates piling up in your trust store.

   **macOS:**

   ```bash
   # Remove old step-ca root CAs
   sudo security delete-certificate -c "Step Certificates Root CA" /Library/Keychains/System.keychain
   # Trust the new one
   sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain step-root-ca.crt
   ```

   **Linux:**

   ```bash
   sudo cp step-root-ca.crt /usr/local/share/ca-certificates/
   sudo update-ca-certificates
   ```

   **Windows (PowerShell as Administrator):**

   ```powershell
   # Remove old step-ca root CAs
   Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -like "*Step Certificates*" } | Remove-Item
   # Trust the new one
   Import-Certificate -FilePath step-root-ca.crt -CertStoreLocation Cert:\LocalMachine\Root
   ```

   **Firefox:** Settings > Privacy & Security > Certificates > View Certificates > Authorities > delete old "Step Certificates Root CA" entries, then Import

5. **Verify the lab services are accessible over HTTPS**

   Open the following URLs in your browser and confirm no certificate warnings:
   - [https://grafana.lab.internal](https://grafana.lab.internal)
   - [https://traefik.lab.internal/dashboard/](https://traefik.lab.internal/dashboard/)

   If you encounter certificate errors, restart Step CA and wait for it to be ready, then restart Traefik:

   ```bash
   kubectl rollout restart statefulset step-ca-step-certificates -n traefik
   kubectl rollout status statefulset step-ca-step-certificates -n traefik --timeout=60s

   kubectl rollout restart deployment traefik -n traefik
   kubectl rollout status deployment traefik -n traefik --timeout=60s
   ```

6. **Bootstrap platform secrets interactively**

   ```bash
   lab-secrets
   ```

## Included Tools

| Tool | Version | Purpose |
|------|---------|---------|
| argocd | 3.3.0 | GitOps CD |
| awscli | v2 | AWS CLI |
| fzf | 0.67.0 | Tool |
| go | 1.23.5 | For operators/tools |
| helm | 4.1.0 | Package manager |
| k9s | 0.50.18 | Terminal UI |
| kind | 0.31.0 | Local K8s clusters |
| krew | 0.4.5 | kubectl plugin manager |
| kubectl | 1.34.4 | K8s CLI |
| kubectx | 0.9.5 | Tool |
| kustomize | 5.6.0 | K8s config management |
| step_cli | 0.29.0 | Tool |
| stern | 1.31.0 | Log tailing |
| terraform | 1.14.3 | Infrastructure as Code |
| yq | 4.52.4 | Tool |

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
localstack-start                     # Start/restart stopped container
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
lab-secrets            # Bootstrap platform secrets interactively
patch-coredns          # Patch CoreDNS for lab.internal DNS forwarding
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
