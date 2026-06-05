#!/usr/bin/env bash
# backup.sh — Hourly backup of SQLite + DuckDB databases
# Usage: Add to crontab: 0 * * * * /home/evans/Project/superapp/scripts/backup.sh
set -euo pipefail

BACKUP_DIR="/home/evans/backups/superapp"
DATE=$(date +%Y%m%d_%H%M%S)
KEEP_DAYS=7

mkdir -p "$BACKUP_DIR"

# Backup SQLite (superapp.db)
SQLITE_SRC="/home/evans/Project/superapp/services/api_gateway/data/superapp.db"
if [ -f "$SQLITE_SRC" ]; then
  sqlite3 "$SQLITE_SRC" ".backup '$BACKUP_DIR/superapp_$DATE.db'"
  echo "[$(date)] SQLite backup: superapp_$DATE.db"
fi

# Backup DuckDB (scholarships)
DUCKDB_SRC="/home/evans/Project/superapp/services/beasiswa_crawler/data/scholarships.duckdb"
if [ -f "$DUCKDB_SRC" ]; then
  cp "$DUCKDB_SRC" "$BACKUP_DIR/scholarships_$DATE.duckdb"
  echo "[$(date)] DuckDB backup: scholarships_$DATE.duckdb"
fi

# Backup VTON job database
VTON_SRC="/home/evans/Project/superapp/services/vton_proxy/data/vton_jobs.db"
if [ -f "$VTON_SRC" ]; then
  sqlite3 "$VTON_SRC" ".backup '$BACKUP_DIR/vton_jobs_$DATE.db'"
  echo "[$(date)] VTON backup: vton_jobs_$DATE.db"
fi

# Cleanup old backups
find "$BACKUP_DIR" -name "*.db" -o -name "*.duckdb" | while read f; do
  if [ "$(find "$f" -mtime +$KEEP_DAYS 2>/dev/null)" ]; then
    rm -f "$f"
    echo "[$(date)] Cleaned: $(basename "$f")"
  fi
done

echo "[$(date)] Backup complete. Files in $BACKUP_DIR:"
ls -lh "$BACKUP_DIR"/*_$DATE.* 2>/dev/null || true
