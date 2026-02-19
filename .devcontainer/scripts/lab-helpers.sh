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

# Patch CoreDNS for lab.internal DNS forwarding
patch-coredns() {
    if ! kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}' 2>/dev/null | grep -q "lab.internal"; then
        echo -e "${YELLOW}🔧 Configuring CoreDNS for lab.internal DNS forwarding...${NC}"
        while true; do
            printf "  Enter Technitium DNS server IP (empty to skip): " && read -r TECHNITIUM_IP
            if [[ -z "$TECHNITIUM_IP" ]]; then
                echo -e "${YELLOW}⚠️  Skipped CoreDNS patching (no IP provided)${NC}"
                return 0
            elif ! [[ "$TECHNITIUM_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo -e "${RED}❌ Invalid IP address: ${TECHNITIUM_IP}${NC}"
                continue
            else
                break
            fi
        done

        if [[ -n "$TECHNITIUM_IP" ]]; then
            kubectl patch configmap coredns -n kube-system --type merge -p "{
              \"data\": {
                \"Corefile\": \"lab.internal:53 {\\n    errors\\n    cache 30\\n    forward . ${TECHNITIUM_IP}\\n}\\n.:53 {\\n    errors\\n    health {\\n       lameduck 5s\\n    }\\n    ready\\n    kubernetes cluster.local in-addr.arpa ip6.arpa {\\n       pods insecure\\n       fallthrough in-addr.arpa ip6.arpa\\n       ttl 30\\n    }\\n    prometheus :9153\\n    forward . /etc/resolv.conf {\\n       max_concurrent 1000\\n    }\\n    cache 30 {\\n       disable success cluster.local\\n       disable denial cluster.local\\n    }\\n    loop\\n    reload\\n    loadbalance\\n}\\n\"
              }
            }"

            # Restart CoreDNS to apply changes
            echo -e "${YELLOW}♻️  Restarting CoreDNS...${NC}"
            kubectl rollout restart deployment coredns -n kube-system
            kubectl rollout status deployment coredns -n kube-system --timeout=60s

            # Verify DNS resolution
            echo -e "${YELLOW}🔍 Verifying DNS resolution inside the cluster...${NC}"
            if kubectl run dns-test --rm -i --restart=Never --image=busybox -- nslookup grafana.lab.internal 2>/dev/null; then
                echo -e "${GREEN}✅ DNS resolution verified${NC}"
            else
                echo -e "${YELLOW}⚠️  DNS verification failed (Technitium may not be reachable from the cluster)${NC}"
            fi
        fi
    else
        echo -e "${GREEN}✅ CoreDNS already configured for lab.internal${NC}"
    fi
}

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
    fi

    # Patch CoreDNS for lab.internal DNS forwarding
    patch-coredns

    # Deploy platform & lab ArgoCD applications
    echo -e "${YELLOW}📦 Deploying platform & lab applications...${NC}"
    kubectl apply -n argocd -f /workspaces/gitops-lab/argocd-apps/deploy/repo-links.yaml
    echo -e "${GREEN}✅ ArgoCD applications deployed${NC}"

    # Start LocalStack
    localstack-start

    echo ""
    echo -e "${GREEN}✅ Lab is ready!${NC}"
    echo -e "${YELLOW}💡 Run 'argo-ui' to port-forward ArgoCD UI and get admin credentials${NC}"
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

# Bootstrap platform secrets interactively
lab-secrets() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Bootstrap Platform Secrets${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # 1. Infisical secrets (infisical namespace)
    echo -e "${YELLOW}[1/3] Infisical Application Secrets${NC}"
    echo -e "  Namespace: infisical | Secret: infisical-secrets"
    echo ""

    printf "  AUTH_SECRET (leave empty to auto-generate): " && read -r INFISICAL_AUTH_SECRET
    if [[ -z "$INFISICAL_AUTH_SECRET" ]]; then
        INFISICAL_AUTH_SECRET=$(openssl rand -base64 32)
        echo -e "  ${GREEN}Auto-generated AUTH_SECRET${NC}"
    fi

    printf "  ENCRYPTION_KEY (leave empty to auto-generate): " && read -r INFISICAL_ENCRYPTION_KEY
    if [[ -z "$INFISICAL_ENCRYPTION_KEY" ]]; then
        INFISICAL_ENCRYPTION_KEY=$(openssl rand -hex 16)
        echo -e "  ${GREEN}Auto-generated ENCRYPTION_KEY${NC}"
    fi

    printf "  SITE_URL [https://infisical.lab.internal]: " && read -r INFISICAL_SITE_URL
    INFISICAL_SITE_URL=${INFISICAL_SITE_URL:-https://infisical.lab.internal}

    kubectl create secret generic infisical-secrets -n infisical \
        --from-literal=AUTH_SECRET="$INFISICAL_AUTH_SECRET" \
        --from-literal=ENCRYPTION_KEY="$INFISICAL_ENCRYPTION_KEY" \
        --from-literal=SITE_URL="$INFISICAL_SITE_URL" \
        --dry-run=client -o yaml | kubectl apply -f -
    echo -e "  ${GREEN}✅ infisical-secrets configured${NC}"

    # Restart Infisical pods to pick up new secrets
    kubectl rollout restart deployment -n infisical 2>/dev/null || true
    echo -e "  ${GREEN}♻️  Restarted infisical pods${NC}"
    echo ""

    # 2. ESO Infisical credentials (external-secrets namespace)
    echo -e "${YELLOW}[2/3] External Secrets - Infisical Credentials${NC}"
    echo -e "  Namespace: external-secrets | Secret: external-secrets-infisical-credentials"
    echo -e "  ${RED}(First, create a Project \"gitops-lab\" and associate it with Machine Identity with Universal Auth)${NC}"
    echo -e "  ${BLUE}- https://infisical.lab.internal/organization/projects${NC}"
    echo -e "  ${BLUE}- https://infisical.lab.internal/organization/access-management?selectedTab=identities${NC}"
    echo ""

    printf "  Infisical Client ID: " && read -r ESO_INFISICAL_CLIENT_ID
    printf "  Infisical Client Secret: " && read -rs ESO_INFISICAL_CLIENT_SECRET
    echo ""

    if [[ -n "$ESO_INFISICAL_CLIENT_ID" && -n "$ESO_INFISICAL_CLIENT_SECRET" ]]; then
        kubectl create secret generic external-secrets-infisical-credentials -n external-secrets \
            --from-literal=clientId="$ESO_INFISICAL_CLIENT_ID" \
            --from-literal=clientSecret="$ESO_INFISICAL_CLIENT_SECRET" \
            --dry-run=client -o yaml | kubectl apply -f -
        echo -e "  ${GREEN}✅ external-secrets-infisical-credentials configured${NC}"

        # Restart ESO pods to pick up new credentials
        kubectl rollout restart deployment -n external-secrets 2>/dev/null || true
        echo -e "  ${GREEN}♻️  Restarted external-secrets pods${NC}"
    else
        echo -e "  ${YELLOW}⚠️  Skipped (empty input)${NC}"
    fi
    echo ""

    # 3. K8sGPT OpenAI secret (k8sgpt-operator namespace)
    echo -e "${YELLOW}[3/3] K8sGPT - OpenAI API Key${NC}"
    echo -e "  Namespace: k8sgpt-operator | Secret: k8sgpt-secret"
    echo ""

    printf "  OpenAI API Key (leave empty to skip): " && read -rs K8SGPT_API_KEY
    echo ""

    if [[ -n "$K8SGPT_API_KEY" ]]; then
        kubectl create secret generic k8sgpt-secret -n k8sgpt-operator \
            --from-literal=ai-api-key="$K8SGPT_API_KEY" \
            --dry-run=client -o yaml | kubectl apply -f -
        echo -e "  ${GREEN}✅ k8sgpt-secret configured${NC}"

        # Restart K8sGPT pods to pick up new API key
        kubectl rollout restart deployment -n k8sgpt-operator 2>/dev/null || true
        echo -e "  ${GREEN}♻️  Restarted k8sgpt-operator pods${NC}"
    else
        echo -e "  ${YELLOW}⚠️  Skipped (empty input)${NC}"
    fi

    echo ""
    echo -e "${GREEN}✅ Secret bootstrap complete!${NC}"
    echo ""
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
localstack-start() {
    if docker ps | grep -q localstack; then
        echo -e "${GREEN}✅ LocalStack already running${NC}"
        return 0
    fi

    # Container exists but stopped — restart it
    if docker ps -a | grep -q localstack; then
        echo -e "${YELLOW}📦 Restarting LocalStack...${NC}"
        docker start localstack
    else
        echo -e "${YELLOW}📦 Starting LocalStack...${NC}"
        docker run -d \
            --name localstack \
            --network host \
            -e SERVICES=s3,sqs,sns,iam,lambda,secretsmanager \
            -e DEBUG=0 \
            -v /var/run/docker.sock:/var/run/docker.sock \
            localstack/localstack:${LOCALSTACK_VERSION}
    fi

    echo -e "${YELLOW}⏳ Waiting for LocalStack...${NC}"
    timeout 60 bash -c 'until curl -s http://localhost:4566/_localstack/health | grep -q "available"; do sleep 2; done' 2>/dev/null || true
    echo -e "${GREEN}✅ LocalStack ready${NC}"
}

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
