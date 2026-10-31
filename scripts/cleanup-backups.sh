#!/bin/sh

set -eu

BACKUP_DIR="/backups"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"

echo "[$(date)] Initiating cleanup of backups..."
echo "Keeping backups of the last ${RETENTION_DAYS} days."

find "$BACKUP_DIR" \
    -maxdepth 1 \
    -type f \
    -name 'lab_db-*.sql' \
    -mtime "+${RETENTION_DAYS}" \
    -print \
    -delete

echo "[$(date)] Cleaning completed."
