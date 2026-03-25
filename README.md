# infra

Dev/test platform and SecRel pipeline. Deploys projects to a Hetzner VPS.

## Quick Start

1. Provision a Hetzner CX32 VPS (Ubuntu 24.04 LTS)
2. Run bootstrap scripts in order: `01-harden.sh` → `02-install-docker.sh` → `03-install-caddy.sh` → `04-setup-secrets.sh` → `05-setup-cleanup-cron.sh`
3. Deploy: `docker compose -f compose/docker-compose.yml -f compose/enforcer/docker-compose.yml up -d`

## Structure

- `bootstrap/` — One-time VPS setup scripts (run in numbered order)
- `compose/` — Docker Compose stacks for shared services and projects
- `.github/workflows/` — Shared SecRel pipeline and deploy workflows
- `k8s/` — Kubernetes manifests (Phase 3, not yet created)
- `docs/` — Operations runbook

## SecRel Pipeline

Projects call the shared workflow:

```yaml
jobs:
  secrel:
    uses: Mountain-Dr3w/infra/.github/workflows/secrel.yml@main
    with:
      dockerfile: ./Dockerfile
      image-name: my-app
```
