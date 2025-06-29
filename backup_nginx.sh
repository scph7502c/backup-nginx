#!/bin/bash
set -euo pipefail

# === Configuration ===
# Define directories – change these to match your environment
BACKUP_DIR="$HOME/backups"
DATE=$(date +%F-%H%M%S)
FILENAME="nginx-full-backup-$DATE.tar.gz"
TEMP_DIR="/tmp/nginx-backup"
LOG_FILE="$HOME/backup-log.txt"
RCLONE_REMOTE="your_remote:your_folder"  # <-- Define this in your rclone config
ARCHIVE_PATH="$BACKUP_DIR/$FILENAME"

# === Setup logging ===
exec >> "$LOG_FILE" 2>&1
echo "=== [$(date '+%Y-%m-%d %H:%M:%S')] Backup started ==="

# === Create necessary directories ===
mkdir -p "$TEMP_DIR"
mkdir -p "$BACKUP_DIR"

# === Create the backup archive ===
echo "[INFO] Creating archive at $(date)"
tar -czf "$TEMP_DIR/$FILENAME" \
    /etc/nginx \
    /var/www \
    /etc/letsencrypt 2>/dev/null || { echo "[ERROR] tar failed at $(date)"; exit 1; }

# === Move archive to backup directory ===
mv -f "$TEMP_DIR/$FILENAME" "$BACKUP_DIR/"
rm -rf "$TEMP_DIR"

# === Validate archive ===
if [ ! -s "$ARCHIVE_PATH" ]; then
    echo "[ERROR] Backup archive is empty or missing. Aborting at $(date)."
    exit 1
fi

# === Local rotation: keep only 7 newest backups ===
echo "[INFO] Cleaning up old local backups..."
cd "$BACKUP_DIR" || exit 1
ls -tp nginx-full-backup-*.tar.gz | grep -v '/$' | tail -n +8 | xargs -r rm --

# === Upload function with fallback ===
upload_to_gdrive() {
    echo "[INFO] Uploading to remote at $(date)..."
    rclone copy "$ARCHIVE_PATH" "$RCLONE_REMOTE" \
        --log-level INFO \
        --log-file "$LOG_FILE" \
        --drive-chunk-size 64M \
        --timeout 5m \
        --retries 2 \
        --low-level-retries 2 \
        --stats-one-line \
        --transfers 1
}

# === First upload attempt ===
upload_to_gdrive

# === Verify upload success ===
if rclone ls "$RCLONE_REMOTE" | grep -q "$FILENAME"; then
    echo "[INFO] Upload successful at $(date)."
else
    echo "[WARN] First attempt failed. Retrying in 10 minutes..."
    sleep 600
    echo "[INFO] Retrying upload at $(date)..."
    upload_to_gdrive

    if rclone ls "$RCLONE_REMOTE" | grep -q "$FILENAME"; then
        echo "[INFO] Upload successful on second attempt at $(date)."
    else
        echo "[ERROR] Upload failed after two attempts at $(date)."
    fi
fi

# === Remote rotation: keep only 7 newest backups ===
echo "[INFO] Cleaning up old backups on remote..."
rclone lsf "$RCLONE_REMOTE" --files-only --format "t" | grep "nginx-full-backup-" | sort -r | tail -n +8 | while read -r file; do
    echo "[INFO] Deleting from remote: $file"
    rclone delete "$RCLONE_REMOTE/$file"
done

echo "[INFO] Backup completed successfully: $ARCHIVE_PATH"
echo
