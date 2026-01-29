#!/bin/bash
set -e

echo "🔧 Running post-create setup..."

# Install Python packages for LocalStack and testing
pip3 install --user --no-build-isolation tomli localstack awscli-local boto3 pytest

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

# Create workspace directory structure
mkdir -p /workspace/{helm-charts,scripts,localstack}

# Create a sample terraform provider config for LocalStack
cat > /workspace/terraform/providers.tf << EOF
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}

# LocalStack AWS provider
provider "aws" {
  access_key                  = "test"
  secret_key                  = "test"
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3             = "http://localhost:4566"
    dynamodb       = "http://localhost:4566"
    sqs            = "http://localhost:4566"
    sns            = "http://localhost:4566"
    iam            = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    secretsmanager = "http://localhost:4566"
  }
}

# Kubernetes provider (uses current context)
provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}
EOF

echo "✅ Post-create setup complete!"

# Install useful krew plugins
echo "📦 Installing krew plugins..."
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
kubectl krew install ctx ns neat tree images node-shell resource-capacity || true

echo "✅ Post-create setup complete!"
