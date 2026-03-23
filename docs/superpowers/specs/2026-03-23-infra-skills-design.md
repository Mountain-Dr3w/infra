# Infra Skills Design Spec

> Date: 2026-03-23

## Overview

Five repo-scoped skills for the infra repo, installed at `.claude/skills/`. Each gives Claude domain expertise and a structured approach for a specific type of work in this platform.

## Skills

### 1. secrel-engineer

**Trigger:** Working on pipeline security — Semgrep rules, Trivy triage, Gitleaks config, SBOM review, ZAP tuning.

**Principles:**
- Hard gates stay hard — never downgrade a gate to a warning
- Triage before action — classify findings before fixing or suppressing
- Tune at the rule level, not the severity level
- SBOM is for audit, not decoration

**Sections:** Pipeline stage reference table, triage flowchart, common false positives per tool, hard-gate rationalization table.

### 2. platform-engineer

**Trigger:** Writing or modifying infrastructure — Docker Compose, k8s manifests, Traefik/Caddy, Flux, networking, resource limits.

**Principles:**
- Respect the resource budget (8GB CX32, tracked per-container)
- Phase awareness — don't suggest tools/patterns from a later phase
- Internal by default — nothing exposed unless explicitly needed
- Follow existing patterns for new services

**Sections:** Architecture reference, "adding a new service" checklist, phase gate table, resource budget tracker, common mistakes.

### 3. incident-response

**Trigger:** Something is broken — deploy failed, crash-loop, HTTPS down, DB connection refused, pipeline red.

**Principles:**
- Observe before acting — collect state first
- Narrowing, not shotgunning — symptoms → component → root cause
- Rollback is always an option
- Document what you find

**Sections:** Triage entry flowchart, diagnostic commands by component, rollback procedures (refs runbook), post-incident checklist.

### 4. vps-operations

**Trigger:** Running commands on or configuring the VPS — bootstrap changes, Caddy config, UFW rules, systemd services, cron.

**Principles:**
- Deploy user, not root
- UFW is the firewall of record (22/80/443 only)
- Systemd overrides for env vars, never /etc/environment
- Bootstrap scripts are source of truth — changes go back into scripts

**Sections:** VPS conventions table, "changing VPS config" checklist, forbidden actions, service management reference.

### 5. gitops-workflow

**Trigger:** Working on deployment flow — image tagging, Flux config, deploy workflow, rollback strategy.

**Principles:**
- One tag computation, referenced everywhere (sha-${GITHUB_SHA::7})
- Know which deploy model you're in (SSH vs GitOps)
- Deploy chain integrity — never skip gates
- Rollback = previous good state, never `latest`

**Sections:** Image tag flow diagram, deploy model comparison, "modifying deploy chain" checklist, tag anti-patterns.

## Installation

All skills at `.claude/skills/<name>/SKILL.md` in the infra repo. Repo-scoped only.

## Registration

Each skill listed in CLAUDE.md with name and trigger description so Claude knows when to invoke them.
