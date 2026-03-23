---
name: platform-engineer
description: Use when writing or modifying infrastructure — Docker Compose stacks, Kubernetes manifests, Traefik or Caddy config, Flux setup, networking rules, resource limits, or adding new services to the platform
---

# Platform Engineer

## Overview

Build and modify infrastructure within the constraints of a single Hetzner CX32 VPS. Every resource decision has a budget. Every config follows established patterns. Know which phase you're in before suggesting solutions.

## When to Use

- Writing or editing Docker Compose files
- Creating Kubernetes manifests (Phase 3+)
- Configuring networking, ingress, or TLS
- Adding a new service to the platform
- Modifying resource limits
- Working on Traefik or Caddy configuration

**When NOT to use:** For security scanning work (use `secrel-engineer`), for debugging broken deployments (use `incident-response`).

## Architecture

```
Internet → Caddy/Traefik (HTTPS) → localhost:PORT → Container
                                                      ↕
                                                 PostgreSQL (127.0.0.1:5432)
```

- **VPS:** Hetzner CX32 — 4 vCPU, 8GB RAM, 80GB disk, Ubuntu 24.04
- **Network:** `infra` Docker network for inter-container communication
- **Database:** Shared PostgreSQL 15, one database per project, internal only
- **TLS:** Auto-cert via Caddy (Phase 1-2) or cert-manager (Phase 3+)

## Resource Budget

| Component | Memory | CPU | Phase |
|-----------|--------|-----|-------|
| PostgreSQL | 1GB | 1.0 | 1-4 |
| Enforcer backend | 512MB | 0.5 | 1-4 |
| k3s baseline | ~512MB | — | 3-4 |
| Flux controllers | ~200MB | — | 4 |
| **OS + system services** | ~1GB | — | all |
| **Remaining headroom** | ~4.8GB | — | — |

Before adding any new service, check this budget. Update the table when allocations change.

## Phase Gate

Read `docs/primer.md` for the current phase. Use only the tools valid for that phase.

| Phase | Valid Tools | Not Yet Valid |
|-------|------------|---------------|
| 1-2 (Compose) | Docker Compose, Caddy, shell scripts | k8s, Traefik, Helm, Flux |
| 3 (k3s) | kubectl, raw manifests, Traefik, cert-manager | Helm, Flux, ArgoCD |
| 4 (GitOps) | Flux, Kustomize | ArgoCD (too heavy for CX32) |

**If you're about to suggest a tool from a later phase, stop.** Note it as a future consideration and use the current-phase equivalent.

## Adding a New Service

### Phase 1-2 (Docker Compose)

1. Create `compose/<service>/docker-compose.yml`
2. Follow the enforcer stack pattern:
   - Explicit `mem_limit` and `cpus`
   - Health check
   - Depends on postgres (if using DB)
   - Connected to `infra` network
   - Image from GHCR with `${IMAGE_TAG}` variable
3. Update resource budget table above
4. Add reverse proxy route in `compose/caddy/Caddyfile` if externally accessible
5. Update `docs/runbook.md` with start/stop commands

### Phase 3+ (Kubernetes)

1. Create `k8s/<service>/` directory
2. Include: namespace, deployment, service, and ingress (if external)
3. Set resource requests AND limits on every container
4. Add health check probes (liveness + readiness)
5. Keep services ClusterIP unless they need ingress
6. Update resource budget table

## Networking Rules

- **Default: internal only.** New services get ClusterIP (k8s) or no port binding (Compose).
- **External access** requires explicit ingress/Caddyfile entry and a reason.
- **PostgreSQL** is never exposed externally. Period.
- **UFW** only allows 22/80/443. Adding a port means updating `01-harden.sh`.
- **Inter-service communication** uses Docker network names (Compose) or service DNS (k8s).

## Common Mistakes

| Mistake | Why It's Wrong | Do This Instead |
|---------|---------------|-----------------|
| No resource limits | One container can OOM the VPS | Always set `mem_limit`/`resources.limits` |
| Exposing ports to host | Bypasses Caddy/Traefik TLS | Use internal networking + reverse proxy |
| Missing health check | No way to know if service is actually working | Add healthcheck in Compose or probes in k8s |
| Suggesting Helm in Phase 3 | Phase 3 is raw manifests, Helm adds complexity | Write plain YAML, consider Kustomize in Phase 4 |
| Missing `depends_on` with healthcheck | Service starts before dependency is ready | Use `depends_on: { postgres: { condition: service_healthy } }` |
