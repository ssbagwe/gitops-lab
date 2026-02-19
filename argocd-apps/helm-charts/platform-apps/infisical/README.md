# Infisical Helm Chart

Wrapper chart for deploying self-hosted [Infisical](https://infisical.com) secret management platform.

## Prerequisites

Before ArgoCD syncs this chart, populate the required secrets:

```bash
kubectl create secret generic infisical-secrets -n infisical \
  --from-literal=AUTH_SECRET="$(openssl rand -base64 32)" \
  --from-literal=ENCRYPTION_KEY="$(openssl rand -hex 16)" \
  --from-literal=SITE_URL="https://infisical.lab.internal" \
  --dry-run=client -o yaml | kubectl apply -f -
```

> The ArgoCD Application uses `ignoreDifferences` on this secret so manually set values are preserved across syncs.

If ArgoCD has already synced the chart before the secrets were populated, restart the pods to pick up the new values:

```bash
kubectl rollout restart deployment -n infisical
```

## Components

- **Infisical** - Secret management platform
- **PostgreSQL** - Backend database (in-cluster)
- **Redis** - Caching layer (in-cluster)
