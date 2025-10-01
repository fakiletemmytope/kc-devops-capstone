# PostgreSQL Database Backup Cron Setup

This directory contains scripts to set up automated PostgreSQL database backups using cron jobs.

## Files

- `pg-db-backup.sh` - The main backup script that creates database dumps and uploads to S3
- `setup-backup-cron.sh` - Idempotent script to install and configure the cron job
- `verify-backup-cron.sh` - Script to verify the cron job setup and status
- `README-backup-cron.md` - This documentation file

## Quick Start

### 1. Set up the cron job

Run the setup script to install the cron job:

```bash
./scripts/setup-backup-cron.sh
```

This script is **idempotent** - you can run it multiple times safely. It will:
- Check if the backup script exists and make it executable
- Install cron if not already installed
- Start the cron service if not running
- Create the log file and directory
- Add or update the cron job to run every 3 days at 2:00 AM

### 2. Verify the setup

Check that everything is configured correctly:

```bash
./scripts/verify-backup-cron.sh
```

This will verify:
- ✅ Backup script exists and is executable
- ✅ Cron service is running
- ✅ Cron job is configured correctly
- ✅ Log file exists
- ✅ Backup directory status
- 📅 Next scheduled run time

## Schedule Details

The backup runs **every 3 days at 2:00 AM** using this cron schedule:
```
0 2 */3 * *
```

This means:
- `0` - At minute 0 (top of the hour)
- `2` - At hour 2 (2:00 AM)
- `*/3` - Every 3rd day of the month
- `*` - Every month
- `*` - Every day of the week

## Monitoring

### View Logs
```bash
# View recent backup logs
tail -f /var/log/pg-backup.log

# View all logs
cat /var/log/pg-backup.log
```

### Check Cron Job
```bash
# List all cron jobs for current user
crontab -l

# Check cron service status
sudo systemctl status cron
# or on some systems:
sudo systemctl status crond
```

### Manual Test
```bash
# Run backup manually to test
./scripts/pg-db-backup.sh
```

## Troubleshooting

### Common Issues

1. **Cron job not running**
   ```bash
   # Check if cron service is running
   sudo systemctl status cron
   
   # Start cron service if stopped
   sudo systemctl start cron
   sudo systemctl enable cron
   ```

2. **Backup script fails**
   ```bash
   # Check logs for errors
   tail -20 /var/log/pg-backup.log
   
   # Test script manually
   ./scripts/pg-db-backup.sh
   ```

3. **Permission issues**
   ```bash
   # Make scripts executable
   chmod +x scripts/*.sh
   
   # Check log file permissions
   ls -la /var/log/pg-backup.log
   ```

4. **Environment variables not loaded**
   - Ensure `$HOME/dream-app/.env` exists and contains required variables
   - Check that `DATABASE_USER` is properly set in the .env file

### Log Analysis

The backup script logs to `/var/log/pg-backup.log`. Look for:
- `Starting backup for dreamvacations...` - Backup started
- `Backup stored at...` - Local backup completed
- `Uploading to S3...` - S3 upload started
- `Upload complete.` - S3 upload finished
- `Backup finished successfully at...` - Entire process completed

### Backup Retention

- **Local backups**: Automatically cleaned up after 7 days
- **S3 backups**: Retention managed by S3 lifecycle policies (if configured)

## Dependencies

The backup system requires:
- Docker (for accessing the PostgreSQL container)
- Python 3 (for S3 upload script)
- AWS credentials configured for S3 access
- Cron service
- Required environment variables in `$HOME/dream-app/.env`

## Security Notes

- The backup script sources environment variables from `$HOME/dream-app/.env`
- Ensure proper file permissions on the `.env` file (600 recommended)
- S3 credentials should follow least-privilege principles
- Log files may contain sensitive information - restrict access appropriately

## Customization

To modify the backup schedule:
1. Edit the `CRON_SCHEDULE` variable in `setup-backup-cron.sh`
2. Run the setup script again to update the cron job

Example schedules:
- Daily at 3 AM: `0 3 * * *`
- Weekly on Sundays at 2 AM: `0 2 * * 0`
- Every 6 hours: `0 */6 * * *`
