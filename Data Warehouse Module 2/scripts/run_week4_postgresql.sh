#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/Users/hoangyugi001/Documents/Coder/IBM Transactions"
PSQL_BIN="${PSQL_BIN:-/opt/homebrew/bin/psql}"
PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5432}"
PGDATABASE="${PGDATABASE:-aml_source}"
PGUSER="${PGUSER:-hoangyugi001}"

if [[ ! -x "$PSQL_BIN" ]]; then
  echo "Không tìm thấy psql tại: $PSQL_BIN"
  echo "Có thể chạy: PSQL_BIN=/duong/dan/psql ./scripts/run_week4_postgresql.sh"
  exit 1
fi

echo "=== IBM AML - WEEK 4 ACCEPTANCE TEST ==="
echo "Database: $PGDATABASE@$PGHOST:$PGPORT"
echo

"$PSQL_BIN" \
  --host "$PGHOST" \
  --port "$PGPORT" \
  --username "$PGUSER" \
  --dbname "$PGDATABASE" \
  --set ON_ERROR_STOP=1 \
  --file "$PROJECT_DIR/sql/05_week4/00_create_week4_qa.sql"

"$PSQL_BIN" \
  --host "$PGHOST" \
  --port "$PGPORT" \
  --username "$PGUSER" \
  --dbname "$PGDATABASE" \
  --set ON_ERROR_STOP=1 \
  --file "$PROJECT_DIR/sql/05_week4/01_run_week4_acceptance.sql"

echo
echo "Hoàn thành. Xem kết quả mới nhất:"
echo "SELECT * FROM qa.v_week4_latest_run;"
echo "SELECT * FROM qa.v_week4_latest_results;"
