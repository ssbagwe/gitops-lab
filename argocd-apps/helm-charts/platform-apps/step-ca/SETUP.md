# step-ca Setup

Private ACME CA for issuing TLS certificates on `lab.internal`.

## Prerequisites

The `step` CLI is pre-installed in the devcontainer (version pinned in `.devcontainer/Dockerfile`).

## Generate CA Configuration

Generate the initial CA config with keys, certs, and an ACME provisioner:

```bash
echo "<step-ca-lab-password>" > /tmp/step-password.txt

step ca init --helm \
  --name "Lab Internal CA" \
  --dns "step-certificates.step-ca.svc.cluster.local" \
  --address ":9000" \
  --provisioner "acme" \
  --acme \
  --password-file /tmp/step-password.txt > /tmp/step-ca-values.yaml

# Remove the default JWK provisioner (only the ACME provisioner is needed)
yq -i 'del(.inject.config.files."ca.json".authority.provisioners[] | select(.type == "JWK"))' /tmp/step-ca-values.yaml

# Extract the intermediate key before removing secrets
yq '.inject.secrets.x509.intermediate_ca_key' /tmp/step-ca-values.yaml > /tmp/step-ca-intermediate-key.pem

# Remove secrets (passwords + private keys) and use existingSecrets instead
yq -i '.inject.secrets = {} | .inject.existingSecrets.enabled = true | .inject.existingSecrets.ca = true' /tmp/step-ca-values.yaml
```

This generates a clean values file with:
- Root and intermediate CA certificates (public only)
- ACME provisioner configuration
- CA fingerprint for client trust
- `existingSecrets` enabled (private keys and passwords are stored in Kubernetes Secrets)

## Update values.yaml

1. Copy the generated `config`, `certificates`, `secrets`, and `existingSecrets` sections from `/tmp/step-ca-values.yaml` into `values.yaml` under `step-certificates.inject`
2. Do NOT put passwords or private keys in `values.yaml` — these go in Kubernetes Secrets (see below)

## Create Kubernetes Secrets (before first deploy)

The chart uses `existingSecrets` to reference pre-created Kubernetes Secrets.
Create them in the `step-ca` namespace before deploying:

```bash
# CA password secret
kubectl create secret generic step-certificates-ca-password \
  -n step-ca \
  --from-literal=password=<step-ca-lab-password>

# Provisioner password secret
kubectl create secret generic step-certificates-provisioner-password \
  -n step-ca \
  --from-literal=password=step-ca-lab-password

# Intermediate CA private key secret
kubectl create secret generic step-certificates-secrets \
  -n step-ca \
  --from-file=intermediate_ca_key=/tmp/step-ca-intermediate-key.pem
```

## ACME Directory URL

Once deployed, the ACME directory is available at:

```
https://step-certificates.step-ca.svc.cluster.local/acme/acme/directory
```

## Traefik Integration

Configure Traefik's `certificatesResolvers` to use this CA:

```yaml
certificatesResolvers:
  stepca:
    acme:
      caServer: https://step-certificates.step-ca.svc.cluster.local/acme/acme/directory
      httpChallenge:
        entryPoint: web
```

Traefik must trust the root CA — the `step-ca-root-ca` ConfigMap is mirrored
to the `traefik` namespace via Reflector and mounted into the Traefik pod.
The `LEGO_CA_CERTIFICATES` env var points Traefik's ACME client to the root CA.
