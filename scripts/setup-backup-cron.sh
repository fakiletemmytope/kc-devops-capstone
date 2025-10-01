#!/bin/bash

# Idempotent script to set up cron job for PostgreSQL database backup
# This script runs every 3 days at 2:00 AM

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SCRIPT="$SCRIPT_DIR/pg-db-backup.sh"
CRON_SCHEDULE="0 2 */3 * *"  # Every 3 days at 2:00 AM
CRON_JOB="$CRON_SCHEDULE $BACKUP_SCRIPT >> /var/log/pg-backup.log 2>&1"
CRON_COMMENT="# PostgreSQL backup job - runs every 3 days at 2:00 AM"

echo "Setting up PostgreSQL backup cron job..."

# Check if backup script exists
if [ ! -f "$BACKUP_SCRIPT" ]; then
    echo "Error: Backup script not found at $BACKUP_SCRIPT"
    exit 1
fi

# Make backup script executable
chmod +x "$BACKUP_SCRIPT"

# Check if cron is installed
if ! command -v crontab &> /dev/null; then
    echo "Installing cron..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y cron
    elif command -v yum &> /dev/null; then
        sudo yum install -y cronie
    else
        echo "Error: Could not install cron. Please install it manually."
        exit 1
    fi
fi

# Start cron service if not running
if ! pgrep -x "cron\|crond" > /dev/null; then
    echo "Starting cron service..."
    if systemctl --version &> /dev/null; then
        sudo systemctl start cron || sudo systemctl start crond
        sudo systemctl enable cron || sudo systemctl enable crond
    else
        sudo service cron start || sudo service crond start
    fi
fi

# Create log directory if it doesn't exist
sudo mkdir -p /var/log
sudo touch /var/log/pg-backup.log
sudo chmod 644 /var/log/pg-backup.log

# Get current crontab
TEMP_CRON=$(mktemp)
crontab -l > "$TEMP_CRON" 2>/dev/null || true

# Check if the job already exists (look for the backup script path)
if grep -Fq "$BACKUP_SCRIPT" "$TEMP_CRON"; then
    echo "Cron job already exists. Updating..."
    # Remove existing job
    grep -Fv "$BACKUP_SCRIPT" "$TEMP_CRON" > "${TEMP_CRON}.tmp" || true
    mv "${TEMP_CRON}.tmp" "$TEMP_CRON"
fi

# Add the new cron job
echo "" >> "$TEMP_CRON"
echo "$CRON_COMMENT" >> "$TEMP_CRON"
echo "$CRON_JOB" >> "$TEMP_CRON"

# Install the updated crontab
crontab "$TEMP_CRON"

# Clean up
rm -f "$TEMP_CRON"

echo "Cron job successfully set up!"
echo "Schedule: Every 3 days at 2:00 AM"
echo "Script: $BACKUP_SCRIPT"
echo "Logs: /var/log/pg-backup.log"
echo ""
echo "To verify the cron job was added, run: crontab -l"
echo "To view backup logs, run: tail -f /var/log/pg-backup.log"
echo ""
echo "Next backup will run at the next scheduled time (every 3 days at 2:00 AM)."
