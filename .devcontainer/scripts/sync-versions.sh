#!/usr/bin/env bash
set -euo pipefail

# sync-versions.sh - Sync tool versions from Dockerfile to README.md
# This script extracts version ARGs from the Dockerfile and updates the README.md table

DOCKERFILE=".devcontainer/Dockerfile"
README="README.md"

# Check if files exist
if [[ ! -f "$DOCKERFILE" ]]; then
    echo "Error: $DOCKERFILE not found"
    exit 1
fi

if [[ ! -f "$README" ]]; then
    echo "Error: $README not found"
    exit 1
fi

# Extract versions from Dockerfile
KUBECTL_VERSION=$(grep "^ARG KUBECTL_VERSION=" "$DOCKERFILE" | cut -d'=' -f2)
HELM_VERSION=$(grep "^ARG HELM_VERSION=" "$DOCKERFILE" | cut -d'=' -f2)
KIND_VERSION=$(grep "^ARG KIND_VERSION=" "$DOCKERFILE" | cut -d'=' -f2)
K9S_VERSION=$(grep "^ARG K9S_VERSION=" "$DOCKERFILE" | cut -d'=' -f2)
TERRAFORM_VERSION=$(grep "^ARG TERRAFORM_VERSION=" "$DOCKERFILE" | cut -d'=' -f2)
ARGOCD_VERSION=$(grep "^ARG ARGOCD_VERSION=" "$DOCKERFILE" | cut -d'=' -f2)
KUSTOMIZE_VERSION=$(grep "^ARG KUSTOMIZE_VERSION=" "$DOCKERFILE" | cut -d'=' -f2)
KREW_VERSION=$(grep "^ARG KREW_VERSION=" "$DOCKERFILE" | cut -d'=' -f2)
GO_VERSION=$(grep "^ARG GO_VERSION=" "$DOCKERFILE" | cut -d'=' -f2)

# Validate that we got all versions
if [[ -z "$KUBECTL_VERSION" || -z "$HELM_VERSION" || -z "$KIND_VERSION" || \
      -z "$K9S_VERSION" || -z "$TERRAFORM_VERSION" || -z "$ARGOCD_VERSION" || \
      -z "$KUSTOMIZE_VERSION" || -z "$KREW_VERSION" || -z "$GO_VERSION" ]]; then
    echo "Error: Failed to extract all versions from $DOCKERFILE"
    exit 1
fi

# Create a temporary file
TMP_FILE=$(mktemp)
trap 'rm -f "$TMP_FILE"' EXIT

# Update README.md
# We'll use awk to replace the version table
awk -v kubectl="$KUBECTL_VERSION" \
    -v helm="$HELM_VERSION" \
    -v kind="$KIND_VERSION" \
    -v k9s="$K9S_VERSION" \
    -v terraform="$TERRAFORM_VERSION" \
    -v argocd="$ARGOCD_VERSION" \
    -v kustomize="$KUSTOMIZE_VERSION" \
    -v krew="$KREW_VERSION" \
    -v go="$GO_VERSION" '
    /^\| kubectl \|/ { print "| kubectl | " kubectl " | K8s CLI |"; next }
    /^\| helm \|/ { print "| helm | " helm " | Package manager |"; next }
    /^\| kind \|/ { print "| kind | " kind " | Local K8s clusters |"; next }
    /^\| k9s \|/ { print "| k9s | " k9s " | Terminal UI |"; next }
    /^\| terraform \|/ { print "| terraform | " terraform " | Infrastructure as Code |"; next }
    /^\| argocd \|/ { print "| argocd | " argocd " | GitOps CD |"; next }
    /^\| kustomize \|/ { print "| kustomize | " kustomize " | K8s config management |"; next }
    /^\| krew \|/ { print "| krew | " krew " | kubectl plugin manager |"; next }
    /^\| go \|/ && /For operators\/tools/ { print "| go | " go " | For operators/tools |"; next }
    { print }
' "$README" > "$TMP_FILE"

# Check if anything changed
if ! diff -q "$README" "$TMP_FILE" > /dev/null 2>&1; then
    cp "$TMP_FILE" "$README"
    echo "✓ Updated $README with versions from $DOCKERFILE"
    echo "  kubectl: $KUBECTL_VERSION"
    echo "  helm: $HELM_VERSION"
    echo "  kind: $KIND_VERSION"
    echo "  k9s: $K9S_VERSION"
    echo "  terraform: $TERRAFORM_VERSION"
    echo "  argocd: $ARGOCD_VERSION"
    echo "  kustomize: $KUSTOMIZE_VERSION"
    echo "  krew: $KREW_VERSION"
    echo "  go: $GO_VERSION"
    exit 1  # Exit 1 to signal pre-commit that file was modified
else
    echo "✓ $README versions are already in sync"
    exit 0
fi
