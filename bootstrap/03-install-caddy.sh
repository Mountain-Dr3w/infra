#!/bin/bash
set -euo pipefail

# Install Caddy from official Cloudsmith apt repository
# Ubuntu 24.04 only, must be run as root

if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root"
    exit 1
fi

# Check if already installed
if command -v caddy &> /dev/null; then
    echo "Caddy is already installed"
    caddy version
    exit 0
fi

echo "Installing Caddy..."

# Install prerequisites
apt-get update
apt-get install -y \
    debian-keyring \
    debian-archive-keyring \
    apt-transport-https \
    curl

# Download and add GPG key
echo "Adding Caddy GPG key..."
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | \
    gpg --batch --yes --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg

# Add apt repository
echo "Adding Caddy apt repository..."
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | \
    tee /etc/apt/sources.list.d/caddy-stable.list

# Install Caddy
apt-get update
apt-get install -y caddy

# Enable systemd service
systemctl enable caddy

echo "Caddy installed successfully!"
echo ""
caddy version
echo ""
echo "Configure /etc/caddy/Caddyfile, then run: systemctl reload caddy"
