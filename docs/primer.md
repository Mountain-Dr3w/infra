# Infra — Project Primer

> Last updated: 2026-03-25
> Updated by: /check-in

## Current Status

VPS is **live and bootstrapped**. Phase 1 is nearly complete — issues #1–6 are done, waiting on **#7 (pipeline end-to-end verification)** which is in progress. Phase 2 SecRel pipeline has been fixed for the username change and is being tested.

## Project Board

https://github.com/users/Mountain-Dr3w/projects/2

## Phase Status

| Phase | Status | Notes |
|-------|--------|-------|
| **1: Docker Compose** | In progress (#7 remaining) | VPS live, bootstrap done, Caddy configured, PostgreSQL running. Awaiting first successful pipeline deploy. |
| **2: SecRel Pipeline** | In progress (testing) | Workflows fixed for lowercase GHCR owner. Awaiting end-to-end verification with #7. |
| **3: k3s Migration** | Not started | Blocked on Phase 1 completion |
| **4: Flux GitOps** | Not started | Blocked on Phase 3 |

## Infrastructure Details

| Resource | Value |
|----------|-------|
| **VPS** | Hetzner CCX13 — 2 dedicated AMD vCPU, 8GB RAM, 80GB disk |
| **Location** | Hillsboro, OR (US West) |
| **IP** | 5.78.201.14 |
| **OS** | Ubuntu 24.04 LTS |
| **Domain** | stavepoint.com (Namecheap) |
| **DNS** | A records: `@` and `*` → 5.78.201.14 |
| **GitHub username** | Mountain-Dr3w (changed from DrewUXDesign) |

### Open Issues

#### Phase 1 — VPS Setup (manual)
- [ ] #7 — Push test commit to verify full pipeline (in progress)

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

- [x] #1 — Buy a domain → stavepoint.com (Namecheap)
- [x] #2 — Sign up for Hetzner and add payment method
- [x] #3 — Provision VPS on Hetzner → CCX13 in Hillsboro, OR (shared vCPU not available in US)
- [x] #4 — Configure DNS A records → Namecheap, @ and * → 5.78.201.14
- [x] #5 — Run bootstrap scripts on VPS → all 5 scripts completed, Caddy configured
- [x] #6 — Configure GitHub Actions secrets in Basemark repo → VPS_HOST, VPS_USER, DEPLOY_SSH_KEY

## What's Ready to Do Now

**#7 — Push test commit to verify full pipeline.** A fresh push to `backend/` in Basemark is needed to trigger the pipeline with the fixed workflows. Once #7 passes, Phase 1 and 2 are complete and Phase 3 work is unblocked.

## Known Issues / Fixes Applied

- **GitHub username change** (DrewUXDesign → Mountain-Dr3w): Broke reusable workflow references in Basemark CI and caused uppercase characters in GHCR image tags. Fixed in both `secrel.yml` and `deploy-compose.yml` by lowercasing `github.repository_owner`.
- **Basemark CI `paths` filter**: Workflow only triggers on changes to `backend/**` or `.github/workflows/ci.yml`. Frontend paths should be added once frontend exists.
- **Basemark CI permissions**: Added top-level `permissions: packages: write` to allow SecRel workflow to push to GHCR.
- **Hetzner US locations**: Shared vCPU (CX) instances are not available in US datacenters. Used dedicated vCPU (CCX13) instead — $13.49/mo vs the planned €7.49/mo for CX32.
- **GHCR pull unauthorized on VPS**: The deploy workflow SSHes into the VPS and runs `docker pull`, but GHCR packages are private by default. Fixed by adding a `GHCR_TOKEN` secret to `deploy-compose.yml` — callers pass `${{ secrets.GITHUB_TOKEN }}`. The VPS runs `docker login ghcr.io` before pulling.
- **VPS `/opt/infra` owned by root**: The repo was cloned as root during bootstrap, so the deploy user couldn't read `.env`, compose files, or write backups. Fix: `chown -R deploy:deploy /opt/infra` (added to runbook bootstrap steps). Must be run once on existing VPS.
- **Deploy user has no passwordless sudo**: `01-harden.sh` adds the deploy user to the `sudo` group but sets no password and doesn't configure NOPASSWD. All `sudo` commands fail in non-interactive SSH sessions. Deploy workflow must not use `sudo`.
- **Pre-migration backups path**: Changed from `/opt/infra/backups/` to `~/backups/` (`/home/deploy/backups/`) since the deploy user owns their home directory.

## Recent Decisions

- Image tags: `sha-${GITHUB_SHA::7}` computed once, passed through pipeline
- Caddy domain: systemd override (not `/etc/environment`)
- Flux chosen over ArgoCD for Phase 4 (RAM constraints)
- CCX13 (dedicated) in Hillsboro instead of CX32 (shared) — US locations don't offer shared vCPU
- RSA-4096 SSH key used (Hetzner didn't accept ed25519)

## Related Repos

- **Basemark** (formerly Enforcer): First project deployed on this platform. CI workflow calls this repo's shared SecRel + deploy workflows. Repo: `Mountain-Dr3w/Basemark`
