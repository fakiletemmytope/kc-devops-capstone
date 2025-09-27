#!/bin/bash
set -e
set -a                                      # auto-export variables
source $HOME/dream-app/.env                 # load file
set +a

# ===== CONFIG =====
CONTAINER_NAME=dream-app-database-1         # your Postgres container name
DB_NAME=dreamvacations                      # database name
DB_USER=$DATABASE_USER                      # db user
BACKUP_DIR=/var/backups/postgres            # local backup dir
DATE=$(date +%F_%H-%M)
BACKUP_FILE=$BACKUP_DIR/${DB_NAME}_${DATE}.sql.gz

# ===== CREATE BACKUP DIR IF NOT EXISTS =====
mkdir -p $BACKUP_DIR

# ===== RUN BACKUP =====
echo "Starting backup for $DB_NAME..."
docker exec -t $CONTAINER_NAME pg_dump -U $DB_USER $DB_NAME | gzip > $BACKUP_FILE
echo "Backup stored at $BACKUP_FILE"

# ===== UPLOAD TO S3 =====
echo "Uploading to S3..."
python3 "$HOME/dream-app/save_to_s3.py" "$BACKUP_FILE"  # Use full path to Python script
echo "Upload complete."

# ===== CLEAN OLD LOCAL BACKUPS (7 days) =====
find $BACKUP_DIR -type f -mtime +7 -name "*.gz" -exec rm {} \;

echo "Backup finished successfully at $(date)"
