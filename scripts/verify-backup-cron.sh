#!/bin/bash

# Script to verify the PostgreSQL backup cron job setup

set -e

echo "Verifying PostgreSQL Backup Cron Job Setup"
echo "=============================================="

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SCRIPT="$SCRIPT_DIR/pg-db-backup.sh"
LOG_FILE="/var/log/pg-backup.log"

echo ""
echo "1. Checking if backup script exists..."
if [ -f "$BACKUP_SCRIPT" ]; then
    echo "Backup script found: $BACKUP_SCRIPT"
    if [ -x "$BACKUP_SCRIPT" ]; then
        echo "Backup script is executable"
    else
        echo "Backup script is not executable"
    fi
else
    echo "Backup script not found: $BACKUP_SCRIPT"
fi

echo ""
echo "2. Checking cron service status..."
if command -v systemctl &> /dev/null; then
    if systemctl is-active --quiet cron || systemctl is-active --quiet crond; then
        echo "Cron service is running"
    else
        echo "Cron service is not running"
    fi
elif command -v service &> /dev/null; then
    if service cron status &> /dev/null || service crond status &> /dev/null; then
        echo "Cron service is running"
    else
        echo "Cron service is not running"
    fi
else
    echo "Cannot determine cron service status"
fi

echo ""
echo "3. Checking cron job configuration..."
if crontab -l 2>/dev/null | grep -q "$BACKUP_SCRIPT"; then
    echo "Cron job found in crontab"
    echo "Current cron job:"
    crontab -l 2>/dev/null | grep -A1 -B1 "$BACKUP_SCRIPT" | sed 's/^/    /'
else
    echo "Cron job not found in crontab"
fi

echo ""
echo "4. Checking log file..."
if [ -f "$LOG_FILE" ]; then
    echo "Log file exists: $LOG_FILE"
    LOG_SIZE=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo "0")
    echo "Log file size: $LOG_SIZE bytes"

    if [ "$LOG_SIZE" -gt 0 ]; then
        echo "Last 5 lines of log file:"
        tail -n 5 "$LOG_FILE" | sed 's/^/    /'
    else
        echo "Log file is empty (no backups have run yet)"
    fi
else
    echo "Log file not found: $LOG_FILE"
fi

echo ""
echo "5. Checking backup directory..."
BACKUP_DIR="/var/backups/postgres"
if [ -d "$BACKUP_DIR" ]; then
    echo "Backup directory exists: $BACKUP_DIR"
    BACKUP_COUNT=$(find "$BACKUP_DIR" -name "*.sql.gz" -type f 2>/dev/null | wc -l)
    echo "Number of backup files: $BACKUP_COUNT"

    if [ "$BACKUP_COUNT" -gt 0 ]; then
        echo "Recent backup files:"
        find "$BACKUP_DIR" -name "*.sql.gz" -type f -exec ls -lh {} \; 2>/dev/null | tail -n 3 | sed 's/^/    /'
    fi
else
    echo "Backup directory not found: $BACKUP_DIR (will be created on first run)"
fi

echo ""
echo "6. Next scheduled run..."
if crontab -l 2>/dev/null | grep -q "$BACKUP_SCRIPT"; then
    CRON_SCHEDULE=$(crontab -l 2>/dev/null | grep "$BACKUP_SCRIPT" | awk '{print $1" "$2" "$3" "$4" "$5}')
    echo "Cron schedule: $CRON_SCHEDULE (Every 3 days at 2:00 AM)"
    echo "Next run will be at the next occurrence of 2:00 AM on a day divisible by 3"
else
    echo "Cannot determine next run time - cron job not found"
fi

echo ""
echo "7. Manual test suggestion..."
echo "To test the backup script manually, run:"
echo "    $BACKUP_SCRIPT"

echo ""
echo "=============================================="
echo "Verification complete!"
