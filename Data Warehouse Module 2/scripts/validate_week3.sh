#!/bin/zsh
set -euo pipefail

PROJECT_DIR="/Users/hoangyugi001/Documents/Coder/IBM Transactions"

echo "PostgreSQL readiness"
pg_isready -h localhost -p 5432

echo "Power BI reporting objects and KPI"
psql -X -v ON_ERROR_STOP=1 -d aml_source \
  -f "$PROJECT_DIR/sql/04_powerbi/01_validate_powerbi_reporting.sql"

echo "Read-only reporting role"
psql -X -v ON_ERROR_STOP=1 -d aml_source -P pager=off -c "
SELECT
    rolname,
    rolcanlogin,
    pg_has_role('powerbi_reader', 'powerbi_readonly', 'member') AS read_only_member,
    rolconfig
FROM pg_roles
WHERE rolname = 'powerbi_reader';"

full_snapshot_count=$(
  rg --files "$PROJECT_DIR/powerbi/data_snapshot" -g '*.csv' | wc -l | tr -d ' '
)
cloud_snapshot_count=$(
  rg --files "$PROJECT_DIR/powerbi/cloud/data_snapshot_compact" -g '*.csv' |
    wc -l | tr -d ' '
)

echo "Full snapshot CSV count: $full_snapshot_count"
echo "Cloud snapshot CSV count: $cloud_snapshot_count"

if [[ "$full_snapshot_count" != "16" ]]; then
  echo "ERROR: expected 16 full snapshot CSV files" >&2
  exit 1
fi

if [[ "$cloud_snapshot_count" != "16" ]]; then
  echo "ERROR: expected 16 cloud snapshot CSV files" >&2
  exit 1
fi

workbook="$PROJECT_DIR/outputs/powerbi_cloud_20260723/IBM_AML_PowerBI_Cloud_Source.xlsx"
if [[ ! -s "$workbook" ]]; then
  echo "ERROR: cloud workbook is missing or empty: $workbook" >&2
  exit 1
fi

unzip -t "$workbook" >/dev/null
echo "Cloud workbook ZIP structure: OK"

links="$PROJECT_DIR/outputs/powerbi_cloud_20260723/POWER_BI_CLOUD_LINKS.txt"
if [[ ! -s "$links" ]]; then
  echo "ERROR: Power BI cloud links file is missing: $links" >&2
  exit 1
fi

echo "Week 3 macOS validation completed."
