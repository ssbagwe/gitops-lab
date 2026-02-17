# GitOps Lab

A self-contained dev container for practicing Kubernetes, ArgoCD, Crossplane, Terraform, and AWS (via LocalStack).

## Table of Contents

- [Prerequisites](#prerequisites)
  - [Install Docker](#install-docker)
  - [Install Technitium DNS](#install-technitium-dns-server-for-private-dns-zone-labinternal)
  - [Configure DNS Forwarding](#configure-dns-forwarding-to-technitium-for-labinternal)
  - [Clone the gitops-lab Repository](#clone-the-gitops-lab-repository)
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

### Install Technitium DNS server for private DNS zone "lab.internal"

- [Technitium DNS Server - Installation](https://github.com/TechnitiumSoftware/DnsServer?tab=readme-ov-file#installation)
- Create a `lab.internal` DNS zone with `grafana.lab.internal` and `traefik.lab.internal` records pointing to the Docker host's IP address

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

#### Windows

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

4. **Patch CoreDNS to forward `lab.internal` DNS queries to Technitium DNS**

   > Replace `<IP_ADDRESS>` with your Technitium DNS server IP

   ```bash
   kubectl patch configmap coredns -n kube-system --type merge -p '{
     "data": {
       "Corefile": "lab.internal:53 {\n    errors\n    cache 30\n    forward . <IP_ADDRESS>\n}\n.:53 {\n    errors\n    health {\n       lameduck 5s\n    }\n    ready\n    kubernetes cluster.local in-addr.arpa ip6.arpa {\n       pods insecure\n       fallthrough in-addr.arpa ip6.arpa\n       ttl 30\n    }\n    prometheus :9153\n    forward . /etc/resolv.conf {\n       max_concurrent 1000\n    }\n    cache 30 {\n       disable success cluster.local\n       disable denial cluster.local\n    }\n    loop\n    reload\n    loadbalance\n}\n"
     }
   }'
   ```

5. **Restart CoreDNS to apply the configuration changes**

   ```bash
   kubectl rollout restart deployment coredns -n kube-system
   ```

6. **Verify DNS resolution inside the cluster**

   ```bash
   kubectl run dns-test --rm -it --restart=Never --image=busybox -- nslookup grafana.lab.internal
   ```

7. **Deploy the platform & lab applications, port forward ArgoCD UI and generate Admin Login creds**

   ```bash
   kubectl apply -n argocd -f /workspaces/gitops-lab/argocd-apps/deploy/repo-links.yaml

   argo-ui
   ```

   <em style="color: green;">Wait for the Applications to deploy and turn green. It will take a while depending on your compute and network.</em>

8. **Import the Step CA root certificate for browser trust**

   ```bash
   kubectl get configmap -n traefik step-ca-step-certificates-certs \
     -o jsonpath='{.data.root_ca\.crt}' > step-root-ca.crt
   ```

   Then import into your OS trust store:
   - **macOS**: `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain step-root-ca.crt`
   - **Linux**: `sudo cp step-root-ca.crt /usr/local/share/ca-certificates/ && sudo update-ca-certificates`
   - **Windows**: Double-click the `.crt` > Install Certificate > Local Machine > Trusted Root Certification Authorities
   - **Firefox**: Settings > Privacy & Security > Certificates > View Certificates > Authorities > Import

9. **Verify the lab services are accessible over HTTPS**

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
