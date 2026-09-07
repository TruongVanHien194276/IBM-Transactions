#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/Users/hoangyugi001/Documents/Coder/IBM Transactions"
DATABASE_NAME="aml_source"
BACKUP_FILE="$PROJECT_DIR/backups/aml_source.backup"

mkdir -p "$PROJECT_DIR/backups"

pg_dump \
  --dbname="$DATABASE_NAME" \
  --format=custom \
  --compress=6 \
  --file="$BACKUP_FILE"

pg_restore --list "$BACKUP_FILE" >/dev/null

echo "Backup PostgreSQL hợp lệ: $BACKUP_FILE"
