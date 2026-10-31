#!/bin/sh

set -u

TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
BACKUP_FILE="/backups/${PGDATABASE}-${TIMESTAMP}.sql"
TEMP_FILE="${BACKUP_FILE}.tmp"

echo "[$(date)] Starting ${PGDATABASE} backup..."''

if pg_dump -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" > "$TEMP_FILE"; then
    if [ -s "$TEMP_FILE" ]; then
        mv "$TEMP_FILE" "$BACKUP_FILE"
        echo "[$(date)] Backup finish: $BACKUP_FILE"
    else
        rm -f "$TEMP_FILE"
        echo "[$(date)] ERRO: empty backup." >&2
        exit 1
    fi
else
    rm -f "$TEMP_FILE"
    echo "[$(date)] ERROR trying to run pg_dump." >&2
    exit 1
fi
