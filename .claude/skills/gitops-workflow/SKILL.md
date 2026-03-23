---
name: gitops-workflow
description: Use when working on the deployment flow — image tagging strategy, Flux configuration, modifying deploy workflows, rollback procedures, or anything involving how code becomes a running container on the VPS
---

# GitOps Workflow

## Overview

Code becomes a running container through a specific chain: push → test → secrel → deploy. The image tag is computed once and flows through the entire chain. Know which deploy model you're in. Don't break the chain. Don't create shortcuts.

## When to Use

- Modifying `secrel.yml` or `deploy-compose.yml` workflows
- Working on Flux configuration (Phase 4)
- Changing how image tags are computed or passed
- Debugging a deploy that used the wrong image
- Setting up rollback procedures
- Any work touching the path from "code committed" to "container running"

## Image Tag Flow

The tag `sha-${GITHUB_SHA::7}` is computed **once** in `secrel.yml` at the `set-tag` step and passed as a workflow output.

```
secrel.yml (compute)
  └─ steps.set-tag: echo "tag=sha-${GITHUB_SHA::7}"
       │
       ├─ Used for: docker build --tag (build-scan-push job)
       ├─ Used for: trivy scan target
       ├─ Used for: syft SBOM target
       ├─ Used for: docker push tags
       │
       └─ Output: jobs.build-scan-push.outputs.image-tag
              │
              └─ Consumed by: deploy-compose.yml (inputs.image-tag)
                    │
                    └─ Used for: docker pull + IMAGE_TAG env var on VPS
```

**The tag is never recomputed.** It originates in one place and is passed by reference everywhere else.

## Deploy Models

| | Phase 1-2 (Current) | Phase 4 (Target) |
|---|---|---|
| **Mechanism** | SSH to VPS via `deploy-compose.yml` | Commit tag to repo, Flux applies |
| **Trigger** | secrel job outputs tag → deploy job SSHs | secrel job outputs tag → workflow commits to infra repo |
| **Rollback** | `export IMAGE_TAG=sha-<old> && docker compose up -d` | `git revert <commit>` in infra repo |
| **Secrets needed** | `VPS_HOST`, `VPS_USER`, `DEPLOY_SSH_KEY` | GitHub token (to push to infra repo) |
| **VPS access** | Direct SSH from GitHub Actions | None — Flux pulls from repo |

**Don't mix models.** In Phase 1-2, deploys go through SSH. In Phase 4, deploys go through Git commits. The transition happens when Flux is configured and proven stable.

## Deploy Chain Integrity

```
push → test → secrel → deploy
```

Every link depends on the previous:
- **test** must pass before secrel runs (`needs: test`)
- **secrel** must pass before deploy runs (`needs: secrel`)
- **deploy** only runs on main branch push (`if: github.ref == 'refs/heads/main'`)

**Never create shortcuts:**

| Shortcut | Why It's Dangerous |
|----------|-------------------|
| Deploy without secrel | Unscanned image in production |
| Deploy from branch | Untested code in production |
| Manual `docker pull` on VPS | Bypasses the entire chain, no audit trail |
| Recompute tag in deploy step | Risk of mismatch with what secrel scanned |
| Use `latest` tag for deploy | No way to know what's actually running |

## Modifying the Deploy Chain

Before changing any workflow file:

1. **Read the current flow** — trace the tag from computation through deploy
2. **Identify what you're changing** — is it the tag format? a new stage? the deploy target?
3. **Verify tag continuity** — after your change, can you trace the tag from `set-tag` to the running container without a gap?
4. **Check gate ordering** — hard gates (Gitleaks, Semgrep, Trivy) must still block the deploy
5. **Test with a real push** — workflow changes can't be tested locally; push and verify

## Tag Anti-Patterns

| Pattern | Problem | Correct Approach |
|---------|---------|-----------------|
| `echo "tag=sha-${GITHUB_SHA::7}"` in multiple places | Drift risk — if one changes, they mismatch | Compute once in secrel, pass as output |
| Using `latest` for deploys | Can't tell what's running, can't rollback reliably | Always use `sha-XXXXXXX` |
| Hardcoding a tag | Breaks automation, gets stale | Use the pipeline output |
| Tagging with branch name | Branches are mutable, same tag points to different images over time | SHA-based tags are immutable |
| Recomputing tag in deploy workflow | May not match what secrel scanned | Use `inputs.image-tag` passed from secrel |

## Rollback Reference

**Phase 1-2 (Compose):**
```bash
cd /opt/infra
export IMAGE_TAG=sha-<previous-good-sha>
docker compose -f compose/docker-compose.yml -f compose/enforcer/docker-compose.yml up -d enforcer-backend
```

**Phase 4 (GitOps):**
```bash
# Revert the commit that updated the image tag
git revert <commit-sha>
git push origin main
# Flux detects the change and rolls back automatically
```
