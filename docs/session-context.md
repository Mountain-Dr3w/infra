# Dev Platform Session Context

> **Purpose:** Captures everything from the 2026-03-23 session so work can continue in a separate context without losing state.

---

## What Was Built

### Infra Repo: https://github.com/DrewUXDesign/infra

A self-hosted dev/test platform and SecRel pipeline. Reusable across projects. Enforcer is the first deployment.

**All files on `main`, pushed to GitHub:**

| File | Purpose |
|------|---------|
| `bootstrap/01-harden.sh` | Deploy user creation, SSH key-only auth, UFW (22/80/443), fail2ban, unattended upgrades |
| `bootstrap/02-install-docker.sh` | Docker Engine + Compose plugin from official apt repo |
| `bootstrap/03-install-caddy.sh` | Caddy web server from Cloudsmith repo |
| `bootstrap/04-setup-secrets.sh` | Interactive — prompts for PG password + domain, creates `.env` with `chmod 600` |
| `bootstrap/05-setup-cleanup-cron.sh` | Weekly cron: `docker system prune --filter "until=168h"` Sundays at 3am |
| `compose/docker-compose.yml` | Shared PostgreSQL 15 with healthcheck, 1GB mem limit, `infra` network |
| `compose/enforcer/docker-compose.yml` | Enforcer backend: GHCR image, 512MB mem limit, depends on postgres health |
| `compose/.env.example` | Template for required env vars |
| `compose/caddy/Caddyfile` | Reverse proxy: `{$DOMAIN}` → `localhost:3001` |
| `.github/workflows/secrel.yml` | Shared SecRel pipeline (called workflow) — Gitleaks → Semgrep → Docker build → Trivy → Syft → push to GHCR |
| `.github/workflows/deploy-compose.yml` | Reusable deploy workflow — SSH to VPS, pg_dump backup, run migrations, pull new image, restart |
| `docs/runbook.md` | Step-by-step VPS setup guide + common operations reference |
| `.gitignore` | Prevents committing `.env` files |
| `README.md` | Repo overview + quick start |

### Enforcer Repo (Basemark): PR #48 Merged

| File | Purpose |
|------|---------|
| `backend/Dockerfile` | Multi-stage build, `node:20-alpine`, non-root `appuser`, healthcheck, `--omit=dev` |
| `backend/.dockerignore` | Excludes `node_modules`, `*.test.js`, `.env`, `.git`, `coverage/` |
| `.github/workflows/ci.yml` | CI pipeline: lint + test (with PG service) → SecRel → deploy to dev |

---

## Design Decisions

### Image Tagging
- Tags use `sha-<7char>` format (e.g., `sha-abc1234`)
- Computed once in SecRel workflow via `echo "tag=sha-${GITHUB_SHA::7}"`
- Passed as output to deploy workflow — no multi-line tag issues
- Images also tagged `latest` on default branch

### Caddy Domain Config
- Caddy runs as a **system service** (not in Docker) for simpler networking
- `{$DOMAIN}` placeholder in Caddyfile resolved via **systemd override**, NOT `/etc/environment`
- Override at `/etc/systemd/system/caddy.service.d/env.conf`

### PostgreSQL
- Shared instance, one database per project
- Bound to `127.0.0.1:5432` (not exposed to internet)
- Pre-migration `pg_dump` runs automatically before every deploy with migrations

### Deploy User
- Created by `01-harden.sh` with sudo access
- SSH authorized_keys copied from root
- Added to docker group by `02-install-docker.sh`
- GitHub Actions deploys as this user (not root)

### Network Architecture
```
Internet → Caddy (HTTPS, auto-cert) → localhost:3001 → Docker container
                                                         ↕
                                                    PostgreSQL (internal only)
```

### Resource Limits
| Container | Memory | CPU |
|-----------|--------|-----|
| PostgreSQL | 1GB | 1.0 |
| Enforcer backend | 512MB | 0.5 |
| Total Phase 1 | ~1.5GB | — |

### VPS Spec
- **Provider:** Hetzner CX32
- **Specs:** 4 vCPU, 8GB RAM, 80GB disk (~$7-10/mo)
- **OS:** Ubuntu 24.04 LTS
- **Why CX32:** Phase 3 (k3s) needs 8GB. Starting with CX32 avoids mid-project migration.

---

## What's NOT Done Yet (Manual Steps)

These require a human and can't be automated by code agents:

1. **Buy a domain** — `.dev` or `.io`, ~$10-15/year
2. **Sign up for Hetzner** — hetzner.com, add payment method
3. **Provision VPS** — CX32, Ubuntu 24.04, paste SSH public key
4. **Configure DNS** — A record: `yourdomain.dev` → VPS IP, `*.yourdomain.dev` → VPS IP
5. **SSH into VPS and run bootstrap** — follow `docs/runbook.md` steps 3-5
6. **Configure GitHub Actions secrets** in Basemark repo:
   - `VPS_HOST` — VPS IP or domain
   - `VPS_USER` — `deploy`
   - `DEPLOY_SSH_KEY` — private SSH key matching the VPS public key
7. **Push a test commit** to verify the full pipeline runs

---

## Phase Roadmap

This session completed **Phase 1 + Phase 2** code artifacts. The platform has 4 phases:

| Phase | Status | What It Does |
|-------|--------|-------------|
| **1: Docker Compose** | Code complete, needs VPS | Enforcer running on VPS behind Caddy with HTTPS |
| **2: SecRel Pipeline** | Code complete, needs VPS | Push → Gitleaks → Semgrep → build → Trivy → Syft → deploy |
| **3: k3s Migration** | Not started | Migrate from Docker Compose to Kubernetes |
| **4: Flux GitOps** | Not started | Zero-SSH deployment via Flux watching the infra repo |

### Phase 3 (k3s) will require:
- Install k3s on VPS
- Learn fundamentals (pods, services, ingress)
- Write Kubernetes manifests for Enforcer (namespace, deployment, service, ingress)
- PostgreSQL as StatefulSet (fresh database, re-seed)
- Traefik replaces Caddy, cert-manager for HTTPS
- OWASP ZAP DAST scanning (runs on GitHub Actions, not on VPS)

### Phase 4 (GitOps) will require:
- Install Flux on k3s (~100-200MB RAM, not ArgoCD which uses 1-2GB)
- Point Flux at `infra` repo's `k8s/` directory
- Deploy step changes: update image tag in repo instead of SSH

---

## Key Documents

| Document | Location | Purpose |
|----------|----------|---------|
| Design spec | `enforcer/docs/superpowers/specs/2026-03-23-dev-platform-secrel-pipeline-design.md` | Full design with all reviewed fixes |
| Implementation plan | `enforcer/docs/superpowers/plans/2026-03-23-dev-platform-phase-1-2.md` | 12-task plan (all complete) |
| Operations runbook | `infra/docs/runbook.md` | Step-by-step VPS setup + operations |
| Enforcer primer | `enforcer/primer.md` | Enforcer project state (updated with #48) |

---

## SecRel Pipeline Flow

```
git push to Basemark/main (backend/** changed)
  │
  ▼
CI Workflow (.github/workflows/ci.yml)
  │
  ├─ Job: test
  │   ├─ Spins up PostgreSQL 15 service container
  │   ├─ npm ci → npm run lint → npm run migrate → npm test
  │   └─ Fails fast on lint/test errors
  │
  ├─ Job: secrel (needs: test)
  │   ├─ Calls: DrewUXDesign/infra/.github/workflows/secrel.yml@main
  │   │
  │   ├─ Stage 1: Gitleaks (secret detection) ← HARD GATE
  │   ├─ Stage 2: Semgrep (SAST) ← HARD GATE
  │   ├─ Stage 3: Docker build → Trivy scan ← HARD GATE → Syft SBOM → Push to GHCR
  │   │
  │   └─ Outputs: image-tag (e.g., sha-abc1234)
  │
  └─ Job: deploy (needs: secrel, only on main push)
      ├─ Calls: DrewUXDesign/infra/.github/workflows/deploy-compose.yml@main
      ├─ SSH to VPS as deploy user
      ├─ pg_dump (pre-migration backup)
      ├─ npm run migrate (inside container)
      ├─ docker compose up -d (new image)
      └─ docker image prune
```

---

## Known Issues / Review Findings Applied

These were caught during spec and plan reviews and already fixed:

1. **Image tag mismatch (Critical)** — Fixed by computing `sha-${GITHUB_SHA::7}` once and referencing everywhere
2. **Caddy env var (Critical)** — Fixed with systemd override instead of `/etc/environment`
3. **No DB migration in pipeline (Critical)** — Added as deploy step with pre-migration pg_dump
4. **ArgoCD too heavy (Important)** — Spec changed to Flux for Phase 4
5. **No deploy user (Important)** — Added to `01-harden.sh`
6. **npm ci --production deprecated (Important)** — Changed to `--omit=dev`
7. **No .gitignore (Minor)** — Added to prevent `.env` commits
8. **Frontend port 5173 (Important)** — Fixed to nginx serving static build (when frontend exists)
9. **No rollback strategy (Important)** — Documented in runbook + deploy workflow handles it
10. **k3s API exposed by default (Important)** — Clarified that UFW blocks port 6443, not k3s defaults
