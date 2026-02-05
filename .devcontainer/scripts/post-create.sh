#!/bin/bash
set -e

echo "🔧 Running post-create setup..."

# Install Python packages for LocalStack and testing
pip3 install --break-system-packages tomli localstack awscli-local

# Set up Terraform plugin cache
mkdir -p ~/.terraform.d/plugin-cache
cat > ~/.terraformrc << EOF
plugin_cache_dir = "$HOME/.terraform.d/plugin-cache"
EOF

# Pre-pull common Helm repos
helm repo add stable https://charts.helm.sh/stable 2>/dev/null || true
helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo update

echo "✅ Post-create setup complete!"

# Install useful krew plugins
echo "📦 Installing krew plugins..."
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
kubectl krew install ctx ns neat tree images node-shell resource-capacity || true

echo "✅ Post-create setup complete!"
