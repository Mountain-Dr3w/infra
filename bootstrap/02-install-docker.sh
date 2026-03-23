#!/bin/bash
set -euo pipefail

# Bootstrap script: Install Docker Engine on Ubuntu 24.04
# Must be run as root
# Idempotent: checks if docker is already installed before proceeding

if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root"
  exit 1
fi

# Check if Docker is already installed
if command -v docker &> /dev/null; then
  echo "Docker is already installed. Skipping installation."
  docker --version
  exit 0
fi

echo "Installing Docker Engine..."

# Update package index
apt-get update

# Install prerequisites
apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release

# Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Set up Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index again
apt-get update

# Install Docker packages
apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

# Enable and start Docker service
systemctl enable docker
systemctl start docker

# Add deploy user to docker group if user exists
DEPLOY_USER="${DEPLOY_USER:-deploy}"
if id "$DEPLOY_USER" &>/dev/null; then
  echo "Adding $DEPLOY_USER to docker group..."
  usermod -aG docker "$DEPLOY_USER"
else
  echo "User $DEPLOY_USER does not exist, skipping docker group addition."
fi

# Print version information
echo ""
echo "Docker installation complete."
docker --version
docker compose version
