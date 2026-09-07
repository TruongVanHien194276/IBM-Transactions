#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/Users/hoangyugi001/Documents/Coder/IBM Transactions"
DATABASE_NAME="aml_source"

cd "$PROJECT_DIR"

if ! command -v psql >/dev/null 2>&1; then
  echo "Không tìm thấy psql. Hãy cài PostgreSQL trước." >&2
  exit 1
fi

if ! psql -d postgres -X -Atqc "SELECT 1 FROM pg_database WHERE datname = '$DATABASE_NAME'" | rg -q '^1$'; then
  createdb --encoding=UTF8 --template=template0 "$DATABASE_NAME"
fi

for TASK_SQL_FILE in \
  01_create_source_schema.sql \
  02_load_landing.sql \
  03_validate_landing.sql \
  04_transform_landing_to_source.sql \
  05_create_indexes_and_views.sql \
  06_validate_source.sql \
  07_cleanup_landing.sql
do
  echo "Running $TASK_SQL_FILE"
  psql -d "$DATABASE_NAME" -X -v ON_ERROR_STOP=1 \
    -f "$PROJECT_DIR/sql/01_source/$TASK_SQL_FILE"
done

echo "Hoàn thành source database PostgreSQL: $DATABASE_NAME"
