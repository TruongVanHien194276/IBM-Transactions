#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/Users/hoangyugi001/Documents/Coder/IBM Transactions"
BACKUP_FILE="$PROJECT_DIR/backups/aml_source.backup"
VERIFY_DATABASE="aml_source_restore_test"

if [[ ! -f "$BACKUP_FILE" ]]; then
  echo "Không tìm thấy backup: $BACKUP_FILE" >&2
  exit 1
fi

if psql -d postgres -X -Atqc "SELECT 1 FROM pg_database WHERE datname = '$VERIFY_DATABASE'" | rg -q '^1$'; then
  echo "Database kiểm thử $VERIFY_DATABASE đã tồn tại; script không ghi đè." >&2
  exit 1
fi

cleanup_restore_test() {
  dropdb --if-exists "$VERIFY_DATABASE" >/dev/null 2>&1 || true
}
trap cleanup_restore_test EXIT

createdb --encoding=UTF8 --template=template0 "$VERIFY_DATABASE"
pg_restore --exit-on-error --dbname="$VERIFY_DATABASE" "$BACKUP_FILE"

psql -d "$VERIFY_DATABASE" -X -v ON_ERROR_STOP=1 <<'SQL'
DO $$
DECLARE
    v_account_rows BIGINT;
    v_transaction_rows BIGINT;
    v_pattern_rows BIGINT;
BEGIN
    SELECT count(*) INTO v_account_rows FROM raw.account;
    SELECT count(*) INTO v_transaction_rows FROM raw.transactions;
    SELECT count(*) INTO v_pattern_rows FROM raw.laundering_pattern_transaction;

    IF v_account_rows <> 2087786
       OR v_transaction_rows <> 31898238
       OR v_pattern_rows <> 22743 THEN
        RAISE EXCEPTION
            'Restore reconciliation failed: account=%, transaction=%, pattern=%',
            v_account_rows, v_transaction_rows, v_pattern_rows;
    END IF;
END
$$;
SQL

echo "Restore test thành công; database kiểm thử sẽ được xóa tự động."
