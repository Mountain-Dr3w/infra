#!/bin/bash
set -euo pipefail

# Bootstrap script: Set up weekly Docker cleanup cron job
# Must be run as root
# Creates a cron job that runs every Sunday at 3:00 AM to clean up Docker resources

if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root"
  exit 1
fi

# Create log directory if it doesn't exist
LOG_DIR="/var/log"
LOG_FILE="$LOG_DIR/docker-cleanup.log"

# Ensure log file exists and is writable
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

# Create the cron file
CRON_FILE="/etc/cron.d/docker-cleanup"

cat > "$CRON_FILE" << 'CRON'
# Docker system cleanup cron job
# Runs every Sunday at 3:00 AM to clean up unused Docker images, containers, and networks
# that haven't been used in the last 168 hours (7 days)

0 3 * * 0 root docker system prune --filter "until=168h" -af >> /var/log/docker-cleanup.log 2>&1
CRON

# Set proper permissions on the cron file
chmod 644 "$CRON_FILE"

# Print summary
echo ""
echo "Docker cleanup cron job setup complete."
echo ""
echo "=== Cron Schedule ==="
echo "Frequency: Every Sunday at 3:00 AM (UTC)"
echo "Command: docker system prune --filter \"until=168h\" -af"
echo ""
echo "=== Log File Location ==="
echo "Log file: $LOG_FILE"
echo ""
echo "=== Cron File Contents ==="
cat "$CRON_FILE"
echo ""
echo "=== Verification ==="
echo "Cron file location: $CRON_FILE"
echo "Cron file permissions:"
ls -l "$CRON_FILE"
