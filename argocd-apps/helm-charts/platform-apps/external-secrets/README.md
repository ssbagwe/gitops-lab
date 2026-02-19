# External Secrets Operator Helm Chart

Wrapper chart for deploying [External Secrets Operator](https://external-secrets.io) with ClusterSecretStore providers for HashiCorp Vault and Infisical.

## Prerequisites

### Vault Provider

Vault is disabled by default. To enable, set `vault.enabled: true` in `values.yaml` and populate the token secret:

```bash
kubectl create secret generic external-secrets-vault-token -n external-secrets \
  --from-literal=token="hvs.your-vault-token" \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Infisical Provider

Infisical is enabled by default. Populate the credentials secret with your Universal Auth machine identity:

```bash
kubectl create secret generic external-secrets-infisical-credentials -n external-secrets \
  --from-literal=clientId="your-client-id" \
  --from-literal=clientSecret="your-client-secret" \
  --dry-run=client -o yaml | kubectl apply -f -
```

> The ArgoCD Application uses `ignoreDifferences` on both secrets so manually set values are preserved across syncs.

If ArgoCD has already synced the chart before the secrets were populated, restart the pods to pick up the new values:

```bash
kubectl rollout restart deployment -n external-secrets
```

## Components

- **External Secrets Operator** - Syncs secrets from external providers into Kubernetes Secrets
- **Vault ClusterSecretStore** - Provider for HashiCorp Vault (KV v2, token auth)
- **Infisical ClusterSecretStore** - Provider for Infisical (universal auth)
