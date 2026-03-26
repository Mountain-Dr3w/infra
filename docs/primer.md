# Infra — Project Primer

> Last updated: 2026-03-26
> Updated by: manual (pipeline debugging session)

## Current Status

**Phases 1 and 2 are complete.** The full pipeline (push → test → SecRel → deploy) is verified end-to-end. Basemark is live at `https://stavepoint.com` with auto-deploy on push to main. Phase 3 (k3s migration) is now unblocked.

## Project Board

https://github.com/users/Mountain-Dr3w/projects/2

## Phase Status

| Phase | Status | Notes |
|-------|--------|-------|
| **1: Docker Compose** | **Complete** | VPS live, Caddy with HTTPS, PostgreSQL, Enforcer deployed and healthy. |
| **2: SecRel Pipeline** | **Complete** | Gitleaks → Semgrep → Docker build → Trivy → Syft → GHCR push → SSH deploy. All gates passing. |
| **3: k3s Migration** | Not started | Unblocked, ready to begin |
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

#### Phase 3 — k3s Migration
- [ ] #8 — Install k3s on VPS
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
- [x] #7 — Full pipeline verified end-to-end (2026-03-26). Required fixes: GHCR auth, VPS file ownership, Caddy env.conf syntax.

## What's Ready to Do Now

**Phase 3 — k3s Migration.** Start with #8 (install k3s on VPS). All Phase 1/2 blockers are resolved.

## Known Issues / Fixes Applied

- **GitHub username change** (DrewUXDesign → Mountain-Dr3w): Broke reusable workflow references in Basemark CI and caused uppercase characters in GHCR image tags. Fixed in both `secrel.yml` and `deploy-compose.yml` by lowercasing `github.repository_owner`.
- **Basemark CI `paths` filter**: Workflow only triggers on changes to `backend/**` or `.github/workflows/ci.yml`. Frontend paths should be added once frontend exists.
- **Basemark CI permissions**: Added top-level `permissions: packages: write` to allow SecRel workflow to push to GHCR.
- **Hetzner US locations**: Shared vCPU (CX) instances are not available in US datacenters. Used dedicated vCPU (CCX13) instead — $13.49/mo vs the planned €7.49/mo for CX32.
- **GHCR pull unauthorized on VPS**: The deploy workflow SSHes into the VPS and runs `docker pull`, but GHCR packages are private by default. Fixed by adding a `GHCR_TOKEN` secret to `deploy-compose.yml` — callers pass `${{ secrets.GITHUB_TOKEN }}`. The VPS runs `docker login ghcr.io` before pulling.
- **VPS `/opt/infra` owned by root**: The repo was cloned as root during bootstrap, so the deploy user couldn't read `.env`, compose files, or write backups. Fix: `chown -R deploy:deploy /opt/infra` (added to runbook bootstrap steps). Must be run once on existing VPS.
- **Deploy user has no passwordless sudo**: `01-harden.sh` adds the deploy user to the `sudo` group but sets no password and doesn't configure NOPASSWD. All `sudo` commands fail in non-interactive SSH sessions. Deploy workflow must not use `sudo`.
- **Pre-migration backups path**: Changed from `/opt/infra/backups/` to `~/backups/` (`/home/deploy/backups/`) since the deploy user owns their home directory.
- **Caddy env.conf syntax error**: The systemd override file had leftover shell commands (`EOF`, `systemctl daemon-reload && systemctl restart caddy`) pasted as literal text. Caddy ignored the bad lines, DOMAIN env var was empty, so Caddy only listened on HTTP port 80 (no HTTPS). Fixed by rewriting the file with correct content only.

## Recent Decisions

- Image tags: `sha-${GITHUB_SHA::7}` computed once, passed through pipeline
- Caddy domain: systemd override (not `/etc/environment`)
- Flux chosen over ArgoCD for Phase 4 (RAM constraints)
- CCX13 (dedicated) in Hillsboro instead of CX32 (shared) — US locations don't offer shared vCPU
- RSA-4096 SSH key used (Hetzner didn't accept ed25519)

## Related Repos

- **Basemark** (formerly Enforcer): First project deployed on this platform. CI workflow calls this repo's shared SecRel + deploy workflows. Repo: `Mountain-Dr3w/Basemark`
