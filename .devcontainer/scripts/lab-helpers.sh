#!/bin/bash
# Lab helper functions - sourced by .zshrc

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Pin LocalStack version
LOCALSTACK_VERSION=4.13.1

# Create the full lab environment
lab-up() {
    echo -e "${BLUE}🚀 Starting GitOps Lab...${NC}"

    # Check Docker
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker is not running${NC}"
        return 1
    fi

    # Create kind cluster if it doesn't exist
    if ! kind get clusters 2>/dev/null | grep -q "^lab$"; then
        echo -e "${YELLOW}📦 Creating kind cluster...${NC}"
        kind create cluster --config ~/.local/kind-config.yaml --name lab

        # Wait for nodes to be ready
        echo -e "${YELLOW}⏳ Waiting for nodes...${NC}"
        kubectl wait --for=condition=Ready nodes --all --timeout=120s
    else
        echo -e "${GREEN}✅ Kind cluster already exists${NC}"
        kind export kubeconfig --name lab
    fi

    # Install ArgoCD
    if ! kubectl get namespace argocd >/dev/null 2>&1; then
        echo -e "${YELLOW}📦 Installing ArgoCD...${NC}"
        kubectl create namespace argocd
        kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side
        echo -e "${YELLOW}⏳ Waiting for ArgoCD...${NC}"
        kubectl wait --namespace argocd \
            --for=condition=ready pod \
            --selector=app.kubernetes.io/name=argocd-server \
            --timeout=180s 2>/dev/null || true

        echo -e "${YELLOW}🔧 Configuring ArgoCD...${NC}"
        # Enable exec feature
        kubectl patch configmap argocd-cm -n argocd --type merge -p '{"data":{"exec.enabled":"true"}}'
        # Add gitops-lab repository
        kubectl apply -n argocd -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: gitops-lab-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: https://github.com/ssbagwe/gitops-lab.git
EOF
        # Add Projects
        kubectl apply -n argocd -f /workspaces/gitops-lab/argocd-apps/projects/
        # Add Repo Link
        # kubectl apply -n argocd -f /workspaces/gitops-lab/argocd-apps/deploy/repo-links.yaml
    fi

    # Start LocalStack
    if ! docker ps | grep -q localstack; then
        echo -e "${YELLOW}📦 Starting LocalStack...${NC}"
        docker run -d \
            --name localstack \
            --network host \
            -e SERVICES=s3,sqs,sns,iam,lambda,secretsmanager \
            -e DEBUG=0 \
            -v /var/run/docker.sock:/var/run/docker.sock \
            localstack/localstack:${LOCALSTACK_VERSION}

        # Wait for LocalStack to be ready
        echo -e "${YELLOW}⏳ Waiting for LocalStack...${NC}"
        timeout 60 bash -c 'until curl -s http://localhost:4566/_localstack/health | grep -q "available"; do sleep 2; done' 2>/dev/null || true
    fi

    echo ""
    echo -e "${GREEN}✅ Lab is ready!${NC}"
    lab-status
}

# Tear down the lab
lab-down() {
    echo -e "${YELLOW}🔻 Tearing down lab...${NC}"

    # Stop LocalStack
    if docker ps -a | grep -q localstack; then
        echo "Stopping LocalStack..."
        docker rm -f localstack 2>/dev/null || true
    fi

    # Delete kind cluster
    if kind get clusters 2>/dev/null | grep -q "^lab$"; then
        echo "Deleting kind cluster..."
        kind delete cluster --name lab
    fi

    echo -e "${GREEN}✅ Lab torn down${NC}"
}

# Full reset
lab-reset() {
    lab-down
    sleep 2
    lab-up
}

# Check status of all components
lab-status() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Lab Status${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Docker
    if docker info >/dev/null 2>&1; then
        echo -e "  Docker:      ${GREEN}✅ Running${NC}"
    else
        echo -e "  Docker:      ${RED}❌ Not running${NC}"
    fi

    # Kind cluster
    if kind get clusters 2>/dev/null | grep -q "^lab$"; then
        echo -e "  Kind:        ${GREEN}✅ Cluster 'lab' exists${NC}"

        # Node count
        NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
        READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready")
        echo -e "  Nodes:       ${GREEN}${READY}/${NODES} Ready${NC}"
    else
        echo -e "  Kind:        ${YELLOW}⚠️  No cluster${NC}"
    fi

    # ArgoCD
    if kubectl get namespace argocd >/dev/null 2>&1; then
        ARGO_READY=$(kubectl get pods -n argocd --no-headers 2>/dev/null | grep -c "Running")
        ARGO_TOTAL=$(kubectl get pods -n argocd --no-headers 2>/dev/null | wc -l)
        echo -e "  ArgoCD:      ${GREEN}✅ ${ARGO_READY}/${ARGO_TOTAL} pods running${NC}"
    else
        echo -e "  ArgoCD:      ${YELLOW}⚠️  Not installed${NC}"
    fi

    # LocalStack
    if docker ps | grep -q localstack; then
        if curl -s http://localhost:4566/_localstack/health | grep -q "available" 2>/dev/null; then
            echo -e "  LocalStack:  ${GREEN}✅ Running${NC}"
        else
            echo -e "  LocalStack:  ${YELLOW}⚠️  Starting...${NC}"
        fi
    else
        echo -e "  LocalStack:  ${YELLOW}⚠️  Not running${NC}"
    fi

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ArgoCD helpers
argo-ui() {
    echo -e "${BLUE}Opening ArgoCD UI on https://localhost:8080${NC}"
    echo -e "${YELLOW}Username: admin${NC}"
    echo -e "${YELLOW}Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)${NC}"
    echo ""
    kubectl port-forward svc/argocd-server -n argocd 8080:443
}

argo-pass() {
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
    echo ""
}

# LocalStack helpers
localstack-status() {
    curl -s http://localhost:4566/_localstack/health | jq .
}

# Quick S3 test
test-s3() {
    echo "Creating test bucket..."
    aws --endpoint-url=http://localhost:4566 s3 mb s3://test-bucket

    echo "Uploading test file..."
    echo "Hello from Platform Lab!" > /tmp/test.txt
    aws --endpoint-url=http://localhost:4566 s3 cp /tmp/test.txt s3://test-bucket/

    echo "Listing bucket..."
    aws --endpoint-url=http://localhost:4566 s3 ls s3://test-bucket/

    echo -e "${GREEN}✅ S3 test passed!${NC}"
}
