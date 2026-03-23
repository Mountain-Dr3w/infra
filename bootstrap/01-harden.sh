#!/bin/bash
set -euo pipefail

# VPS Hardening Bootstrap Script
# Run as root on a fresh Ubuntu 24.04 VPS
# Idempotent: safe to re-run multiple times

echo "=== Starting VPS hardening bootstrap ==="

# Update system packages
echo "=== Updating system packages ==="
apt-get update
apt-get upgrade -y

# Create deploy user with sudo access
echo "=== Creating deploy user ==="
if ! id "deploy" &>/dev/null; then
    useradd -m -s /bin/bash -G sudo deploy
    echo "Deploy user created"
else
    echo "Deploy user already exists"
fi

# Copy root's SSH authorized_keys to deploy user
echo "=== Setting up SSH keys for deploy user ==="
if [ -f /root/.ssh/authorized_keys ]; then
    mkdir -p /home/deploy/.ssh
    cp /root/.ssh/authorized_keys /home/deploy/.ssh/authorized_keys
    chown -R deploy:deploy /home/deploy/.ssh
    chmod 700 /home/deploy/.ssh
    chmod 600 /home/deploy/.ssh/authorized_keys
    echo "SSH keys copied to deploy user"
else
    echo "WARNING: /root/.ssh/authorized_keys not found"
fi

# Configure SSH to use key-only authentication and restrict root login
echo "=== Configuring SSH ==="
# Backup original sshd_config if not already backed up
if [ ! -f /etc/ssh/sshd_config.orig ]; then
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.orig
fi

# Disable password authentication
if grep -q "^#PasswordAuthentication yes" /etc/ssh/sshd_config; then
    sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
elif ! grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
    echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
fi

# Disable password authentication for empty passwords
if grep -q "^#PermitEmptyPasswords" /etc/ssh/sshd_config; then
    sed -i 's/^#PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
elif ! grep -q "^PermitEmptyPasswords no" /etc/ssh/sshd_config; then
    echo "PermitEmptyPasswords no" >> /etc/ssh/sshd_config
fi

# Set PermitRootLogin to prohibit-password
if grep -q "^#PermitRootLogin" /etc/ssh/sshd_config; then
    sed -i 's/^#PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
elif grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config; then
    sed -i 's/^PermitRootLogin yes/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
elif ! grep -q "^PermitRootLogin prohibit-password" /etc/ssh/sshd_config; then
    echo "PermitRootLogin prohibit-password" >> /etc/ssh/sshd_config
fi

# Validate SSH config syntax
if sshd -t; then
    systemctl restart ssh
    echo "SSH configuration updated and reloaded"
else
    echo "ERROR: SSH configuration syntax error"
    exit 1
fi

# Install and configure UFW
echo "=== Installing and configuring UFW ==="
apt-get install -y ufw

# Set default policies
ufw --force enable
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (port 22)
ufw allow 22/tcp comment 'SSH'
# NOTE: For tighter security, replace the line below with: ufw allow from YOUR_IP/32 to any port 22 comment 'SSH (restricted)'

# Allow HTTP (port 80)
ufw allow 80/tcp comment 'HTTP'

# Allow HTTPS (port 443)
ufw allow 443/tcp comment 'HTTPS'

echo "UFW firewall configured"

# Install and configure fail2ban for SSH
echo "=== Installing and configuring fail2ban ==="
apt-get install -y fail2ban

# Create fail2ban local SSH jail configuration
cat > /etc/fail2ban/jail.d/sshd.local << 'EOF'
[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 5
findtime = 600
bantime = 3600
EOF

# Enable and start fail2ban
systemctl enable fail2ban
systemctl restart fail2ban
echo "fail2ban configured and started"

# Enable unattended security updates
echo "=== Enabling unattended security updates ==="
apt-get install -y unattended-upgrades apt-listchanges

# Create automatic security updates configuration
cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Mail "root";
Unattended-Upgrade::MailReport "on-change";
EOF

# Enable unattended-upgrades
if [ ! -f /etc/apt/apt.conf.d/20auto-upgrades ]; then
    cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF
else
    echo "Auto-upgrades already configured"
fi

echo "Unattended security updates enabled"

# Print status
echo "=== Final Status ==="
echo ""
echo "UFW Status:"
ufw status
echo ""
echo "fail2ban Status:"
systemctl status fail2ban --no-pager
echo ""
echo "=== VPS hardening bootstrap completed successfully ==="
