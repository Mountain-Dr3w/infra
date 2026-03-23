---
name: vps-operations
description: Use when running commands on or configuring the VPS — modifying bootstrap scripts, editing Caddy or systemd config, changing UFW rules, managing cron jobs, or any server administration on the Hetzner CX32
---

# VPS Operations

## Overview

The VPS is hardened by bootstrap scripts that are the source of truth. All config changes must flow back into those scripts. Operate as the deploy user, not root. Don't break the hardening.

## When to Use

- Modifying any bootstrap script
- Changing Caddy configuration
- Adding/removing UFW rules
- Managing systemd services or overrides
- Setting up cron jobs
- Any SSH-based server administration

## VPS Conventions

| Item | Value |
|------|-------|
| **OS** | Ubuntu 24.04 LTS |
| **User** | `deploy` (not root) — sudo when needed |
| **Infra path** | `/opt/infra` |
| **Backups path** | `/opt/infra/backups` |
| **Caddy config** | `/etc/caddy/Caddyfile` (copied from repo) |
| **Caddy env override** | `/etc/systemd/system/caddy.service.d/env.conf` |
| **Docker compose root** | `/opt/infra/compose/` |
| **Open ports (UFW)** | 22 (SSH), 80 (HTTP), 443 (HTTPS) — nothing else |
| **SSH auth** | Key-only, password auth disabled |
| **Auto-updates** | unattended-upgrades enabled |
| **Docker cleanup** | Weekly cron, Sundays 3am (`docker system prune --filter "until=168h"`) |

## Bootstrap Scripts (Source of Truth)

| Script | Purpose |
|--------|---------|
| `01-harden.sh` | Deploy user, SSH hardening, UFW, fail2ban, unattended-upgrades |
| `02-install-docker.sh` | Docker Engine + Compose, deploy user in docker group |
| `03-install-caddy.sh` | Caddy from Cloudsmith repo |
| `04-setup-secrets.sh` | Interactive `.env` creation (PG password, domain) |
| `05-setup-cleanup-cron.sh` | Weekly Docker prune cron |

**If you change VPS config, the change goes back into the relevant bootstrap script.** A fresh VPS must be reproducible by running these scripts in order.

## Changing VPS Config Checklist

1. Identify which bootstrap script owns the config
2. Make the change in the bootstrap script (keep it idempotent)
3. Test the change on the live VPS
4. Update `docs/runbook.md` if the operation is user-facing
5. Commit the bootstrap script change

## Environment Variables

**Caddy domain:** Set via systemd override, never `/etc/environment`.

```bash
# Location: /etc/systemd/system/caddy.service.d/env.conf
[Service]
Environment="DOMAIN=yourdomain.dev"
```

After changing:
```bash
sudo systemctl daemon-reload
sudo systemctl restart caddy
```

**Docker Compose:** Variables in `/opt/infra/compose/.env` (created by `04-setup-secrets.sh`, `chmod 600`).

## Forbidden Actions

| Action | Why | Do This Instead |
|--------|-----|-----------------|
| SSH as root | Hardening disables root login for a reason | SSH as `deploy`, use `sudo` when needed |
| Edit `/etc/environment` | Caddy doesn't read it; creates confusion about where env vars live | Use systemd drop-in overrides |
| Open arbitrary ports in UFW | Exposes attack surface | Keep 22/80/443 only. Route through Caddy/Traefik. |
| Edit Caddy's base unit file | Gets overwritten on Caddy updates | Use drop-in override at `caddy.service.d/` |
| Manually install packages without updating bootstrap | Next VPS rebuild will be missing them | Add to the appropriate bootstrap script |
| `chmod 777` anything | Security violation | Use minimum necessary permissions |
| Store secrets in files without restricting permissions | Readable by all users | `chmod 600` for any file with secrets |

## Service Management

**Caddy:**
```bash
sudo systemctl status caddy
sudo systemctl restart caddy
sudo systemctl reload caddy          # Reload config without downtime
journalctl -u caddy --since "1h ago"
```

**Docker:**
```bash
sudo systemctl status docker
docker compose -f compose/docker-compose.yml -f compose/enforcer/docker-compose.yml ps
docker compose -f compose/docker-compose.yml -f compose/enforcer/docker-compose.yml logs -f
```

**UFW:**
```bash
sudo ufw status verbose
sudo ufw allow <port>/tcp            # Only if updating 01-harden.sh too
```

**Cron:**
```bash
crontab -l                           # List current user's cron jobs
sudo crontab -l                      # List root's cron jobs
```
