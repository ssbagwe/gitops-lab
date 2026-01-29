#!/bin/bash

echo "🚀 Starting Platform Engineering Lab..."

# Wait for Docker to be ready
echo "⏳ Waiting for Docker..."
timeout 60 bash -c 'until docker info >/dev/null 2>&1; do sleep 1; done'

if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker not available. Some features may not work."
    exit 0
fi

echo "✅ Docker is ready"

# Check if kind cluster exists
if kind get clusters 2>/dev/null | grep -q "^lab$"; then
    echo "✅ Kind cluster 'lab' already exists"

    # Make sure kubeconfig is set
    kind export kubeconfig --name lab
else
    echo "ℹ️  No cluster found. Run 'lab-up' to create one."
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  GitOps Lab"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Quick commands:"
echo "    lab-up       - Create cluster + install ArgoCD + LocalStack"
echo "    lab-down     - Tear down everything"
echo "    lab-status   - Check what's running"
echo "    lab-reset    - Full reset"
echo ""
echo "  K8s shortcuts:"
echo "    k9s          - Terminal UI for Kubernetes"
echo "    kgp          - kubectl get pods"
echo "    kga          - kubectl get all"
echo ""
echo "  ArgoCD:"
echo "    argo-ui      - Open ArgoCD UI (port-forward)"
echo "    argo-pass    - Get ArgoCD admin password"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
