# Infra — Project Primer

> Last updated: 2026-03-23
> Updated by: /check-in

## Current Status

Phase 1 and Phase 2 code artifacts are **complete and on `main`**. The VPS has **not been provisioned yet** — all Phase 1 issues are blocked on manual setup steps (domain purchase, Hetzner signup, VPS provisioning).

## Phase Status

| Phase | Status | Notes |
|-------|--------|-------|
| **1: Docker Compose** | Code complete, awaiting VPS | Bootstrap scripts, Compose stacks, Caddyfile all on `main` |
| **2: SecRel Pipeline** | Code complete, awaiting VPS | Shared secrel.yml + deploy-compose.yml workflows on `main` |
| **3: k3s Migration** | Not started | Blocked on Phase 1 operational |
| **4: Flux GitOps** | Not started | Blocked on Phase 3 |

## Project Board

https://github.com/users/DrewUXDesign/projects/2

### Open Issues

#### Phase 1 — VPS Setup (manual)
- [ ] #1 — Buy a domain (.dev or .io)
- [ ] #2 — Sign up for Hetzner and add payment method
- [ ] #3 — Provision VPS on Hetzner (blocked by #2)
- [ ] #4 — Configure DNS A records (blocked by #1, #3)
- [ ] #5 — Run bootstrap scripts on VPS (blocked by #3, #4)
- [ ] #6 — Configure GitHub Actions secrets in Basemark repo (blocked by #5)
- [ ] #7 — Push test commit to verify full pipeline (blocked by #6)

#### Phase 3 — k3s Migration
- [ ] #8 — Install k3s on VPS (blocked by #7)
- [ ] #9 — Write Kubernetes manifests for Enforcer (blocked by #8)
- [ ] #10 — Deploy PostgreSQL as StatefulSet (blocked by #8)
- [ ] #11 — Replace Caddy with Traefik + cert-manager (blocked by #9)
- [ ] #12 — Add OWASP ZAP DAST scanning to pipeline (blocked by #11)

#### Phase 4 — Flux GitOps
- [ ] #13 — Install Flux on k3s cluster (blocked by #9, #10, #11)
- [ ] #14 — Configure Flux to watch infra repo k8s/ directory (blocked by #13)
- [ ] #15 — Update deploy workflow to GitOps (blocked by #14)

### Completed Issues

(none yet)

## What's Ready to Do Now

The only unblocked work is the manual VPS setup sequence. Start with:
1. **#1** — Buy a domain
2. **#2** — Sign up for Hetzner

These two can be done in parallel. Everything else chains from there.

## Recent Decisions

- Image tags: `sha-${GITHUB_SHA::7}` computed once, passed through pipeline
- Caddy domain: systemd override (not `/etc/environment`)
- Flux chosen over ArgoCD for Phase 4 (RAM constraints)
- CX32 VPS from the start to avoid mid-project migration for k3s

## Related Repos

- **Enforcer (Basemark):** First project deployed on this platform. PR #48 added Dockerfile, .dockerignore, and CI workflow that calls this repo's shared SecRel + deploy workflows.
