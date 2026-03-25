# Operations Runbook

## Initial Setup (one-time)

### Prerequisites

1. **Hetzner account** — sign up at hetzner.com, add payment method
2. **Domain name** — buy a `.dev` or `.io` domain (~$10-15/year)
3. **SSH key pair** — generate if you don't have one: `ssh-keygen -t ed25519`

### Step 1: Provision VPS

1. Log into Hetzner Cloud console
2. Create server:
   - Location: your preference (US or EU)
   - Image: Ubuntu 24.04
   - Type: CX32 (4 vCPU, 8GB RAM, 80GB disk)
   - SSH key: paste your public key
   - Name: `dev-platform`
3. Note the public IP address

### Step 2: Configure DNS

1. In your domain registrar, create an A record:
   - `yourdomain.dev` → VPS IP
   - `*.yourdomain.dev` → VPS IP (wildcard for subdomains)
2. Wait for propagation (usually 5-30 minutes)
3. Verify: `dig yourdomain.dev` should return the VPS IP

### Step 3: Bootstrap the VPS

```bash
# SSH into the VPS
ssh root@YOUR_VPS_IP

# Clone the infra repo
git clone https://github.com/Mountain-Dr3w/infra.git /opt/infra
cd /opt/infra

# Run bootstrap scripts in order
bash bootstrap/01-harden.sh
bash bootstrap/02-install-docker.sh
bash bootstrap/03-install-caddy.sh
bash bootstrap/04-setup-secrets.sh
bash bootstrap/05-setup-cleanup-cron.sh

# Create backups directory (owned by deploy user)
sudo -u deploy mkdir -p /home/deploy/backups
```

### Step 4: Configure Caddy

```bash
# Copy Caddyfile to system location
cp /opt/infra/compose/caddy/Caddyfile /etc/caddy/Caddyfile

# Set domain env var for Caddy's systemd service
mkdir -p /etc/systemd/system/caddy.service.d
cat > /etc/systemd/system/caddy.service.d/env.conf << EOF
[Service]
Environment="DOMAIN=yourdomain.dev"
EOF
systemctl daemon-reload
systemctl restart caddy
```

### Step 5: Start services

```bash
cd /opt/infra
docker compose -f compose/docker-compose.yml -f compose/enforcer/docker-compose.yml up -d
```

### Step 6: Configure GitHub Actions secrets

In the Basemark repo settings (Settings → Secrets → Actions), add:
- `VPS_HOST` — VPS IP or domain
- `VPS_USER` — `deploy` (created by the hardening script)
- `DEPLOY_SSH_KEY` — private SSH key (the one matching the public key on the VPS)

### Step 7: Verify

1. Visit `https://yourdomain.dev/api/health` — should return health check response
2. Push a commit to Basemark `main` — pipeline should run and deploy automatically

---

## Common Operations

### View logs

```bash
# All services
docker compose -f compose/docker-compose.yml -f compose/enforcer/docker-compose.yml logs -f

# Single service
docker compose -f compose/docker-compose.yml -f compose/enforcer/docker-compose.yml logs -f enforcer-backend
```

### Manual rollback

```bash
cd /opt/infra

# Set image tag to previous commit SHA
export IMAGE_TAG=sha-abc1234
docker compose -f compose/docker-compose.yml -f compose/enforcer/docker-compose.yml up -d enforcer-backend
```

### Restore database from backup

```bash
# List backups (stored in deploy user's home dir)
ls -la /home/deploy/backups/

# Restore
docker compose -f compose/docker-compose.yml exec -T postgres \
    psql -U enforcer enforcer_dev < /home/deploy/backups/pre-migrate-TIMESTAMP.sql
```

### Check disk usage

```bash
df -h
docker system df
```

### Manual image cleanup

```bash
docker system prune --filter "until=168h" -af
```

### Update infra repo on VPS

```bash
cd /opt/infra
git pull origin main
```
