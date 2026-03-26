# Infra Repo — Claude Context

## First Thing

Read `docs/primer.md` before doing anything. It has the current project state, phase status, and what's in progress. The primer is the source of truth for "where are we."

## What This Repo Is

A self-hosted dev/test platform and SecRel (Security Release) pipeline. Deploys projects to a single Hetzner VPS. Enforcer is the first project deployed on it. The repo is designed to be reusable across projects.

**GitHub:** https://github.com/Mountain-Dr3w/infra
**Project board:** https://github.com/users/Mountain-Dr3w/projects/2

## Repo Structure

```
infra/
├── bootstrap/          # One-time VPS setup scripts (run in numbered order)
│   ├── 01-harden.sh        # Deploy user, SSH hardening, UFW, fail2ban
│   ├── 02-install-docker.sh # Docker Engine + Compose
│   ├── 03-install-caddy.sh  # Caddy web server
│   ├── 04-setup-secrets.sh  # Interactive .env creation
│   └── 05-setup-cleanup-cron.sh # Weekly Docker prune
├── compose/            # Docker Compose stacks
│   ├── docker-compose.yml       # Shared PostgreSQL 15
│   ├── enforcer/docker-compose.yml # Enforcer backend
│   ├── caddy/Caddyfile          # Reverse proxy config
│   └── .env.example
├── .github/workflows/  # Shared CI/CD workflows (called by other repos)
│   ├── secrel.yml           # Gitleaks → Semgrep → Docker build → Trivy → Syft → GHCR push
│   └── deploy-compose.yml  # SSH deploy: backup → migrate → pull → restart
├── .claude/
│   ├── commands/
│   │   └── check-in.md          # /check-in — project status + primer sync
│   └── skills/
│       ├── secrel-engineer/     # SecRel pipeline & security scanning
│       ├── platform-engineer/   # Infrastructure & container orchestration
│       ├── incident-response/   # Structured debugging when things break
│       ├── vps-operations/      # VPS admin & hardening conventions
│       └── gitops-workflow/     # Deploy chain & image tag flow
├── k8s/                # Kubernetes manifests (Phase 3, not yet created)
├── docs/
│   ├── primer.md            # Living project state (READ THIS FIRST)
│   ├── runbook.md           # VPS setup guide + operations reference
│   └── session-context.md   # Snapshot from initial build session
└── CLAUDE.md           # This file
```

## Architecture

```
Internet → Caddy (HTTPS, auto-cert) → localhost:3001 → Docker container (Enforcer)
                                                         ↕
                                                    PostgreSQL (127.0.0.1:5432, internal only)
```

- **VPS:** Hetzner CCX13 — 2 dedicated AMD vCPU, 8GB RAM, 80GB disk, Ubuntu 24.04 LTS (Hillsboro, OR)
- **Caddy** runs as a system service (not Docker) for simpler networking
- **Domain env var** set via systemd override at `/etc/systemd/system/caddy.service.d/env.conf`, not `/etc/environment`
- **PostgreSQL** is shared, one database per project, bound to localhost only
- **Deploy user** created by `01-harden.sh`, has docker group, used by GitHub Actions (not root). **No passwordless sudo** — do not use `sudo` in deploy scripts run via SSH.

### Resource Limits

| Container | Memory | CPU |
|-----------|--------|-----|
| PostgreSQL | 1GB | 1.0 |
| Enforcer backend | 512MB | 0.5 |

## SecRel Pipeline

Projects call the shared workflow from their own CI:

```
git push → test (project CI) → secrel (this repo's workflow) → deploy (this repo's workflow)
```

SecRel stages (all hard gates — failure blocks the pipeline):
1. **Gitleaks** — secret detection
2. **Semgrep** — static analysis (SAST)
3. **Docker build** → **Trivy** scan → **Syft** SBOM → push to GHCR

Image tags use `sha-<7char>` format (e.g., `sha-abc1234`), computed once and passed through.

## Phase Roadmap

| Phase | What |
|-------|------|
| **1: Docker Compose** | Enforcer on VPS behind Caddy with HTTPS |
| **2: SecRel Pipeline** | Push-to-deploy with security scanning |
| **3: k3s Migration** | Kubernetes (k3s), Traefik, cert-manager, OWASP ZAP DAST |
| **4: Flux GitOps** | Zero-SSH deploys via Flux watching this repo |

See `docs/primer.md` for which phases are complete.

## Design Decisions to Preserve

- **Image tags:** Always `sha-${GITHUB_SHA::7}`. Computed once, referenced everywhere. No `latest` for deploys.
- **Caddy domain:** Systemd override, not `/etc/environment`.
- **Flux over ArgoCD:** Flux uses ~100-200MB RAM vs ArgoCD's 1-2GB. CX32 can't spare it.
- **Bootstrap scripts are idempotent:** Safe to re-run, but designed for one-time setup.
- **Pre-migration backups:** `pg_dump` runs automatically before every deploy with migrations. Stored in `~/backups/` on the VPS (deploy user's home dir).
- **GHCR auth for deploys:** `deploy-compose.yml` requires a `GHCR_TOKEN` secret. Callers pass `${{ secrets.GITHUB_TOKEN }}`. The VPS runs `docker login ghcr.io` before pulling.
- **VPS `/opt/infra` ownership:** Must be owned by the deploy user (`chown -R deploy:deploy /opt/infra`). Cloned as root during bootstrap, ownership transferred after.

## Skills

This repo has custom skills at `.claude/skills/`. Use them when the trigger matches.

| Skill | When to Use |
|-------|-------------|
| `secrel-engineer` | Security scanning config, triaging findings, tuning Semgrep/Gitleaks/Trivy rules, SBOM review, ZAP config |
| `platform-engineer` | Docker Compose stacks, k8s manifests, Traefik/Caddy, networking, resource limits, adding services |
| `incident-response` | Something is broken — deploy failed, container crash-looping, HTTPS down, DB refused, pipeline red |
| `vps-operations` | Bootstrap script changes, Caddy config, UFW rules, systemd services, cron, any VPS admin |
| `gitops-workflow` | Image tagging, deploy workflow changes, Flux config, rollback procedures |

## Maintaining Project State

The `docs/primer.md` file is the living state document. It gets updated via the `/check-in` command, which reads the GitHub project board, reconciles it with the primer, gives a status report, and writes the updated state back.

When doing significant work in this repo:
- Check the project board for related issues: `gh project item-list 2 --owner Mountain-Dr3w`
- Reference issue numbers in commits when closing work
- Run `/check-in` to sync state after completing work
