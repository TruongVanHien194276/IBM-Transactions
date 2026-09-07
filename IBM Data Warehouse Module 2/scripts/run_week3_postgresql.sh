#!/bin/zsh
set -euo pipefail

PROJECT_DIR="/Users/hoangyugi001/Documents/Coder/IBM Transactions"
PYTHON_BIN="/Users/hoangyugi001/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3"
NODE_BIN="/Users/hoangyugi001/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node"

echo "1/7 Checking PostgreSQL"
pg_isready -h localhost -p 5432

echo "2/7 Creating or updating Power BI reporting views"
psql -X -v ON_ERROR_STOP=1 -d aml_source \
  -f "$PROJECT_DIR/sql/04_powerbi/00_create_powerbi_reporting.sql"

echo "3/7 Validating the reporting layer"
psql -X -v ON_ERROR_STOP=1 -d aml_source \
  -f "$PROJECT_DIR/sql/04_powerbi/01_validate_powerbi_reporting.sql"

echo "4/7 Exporting the full reporting snapshot"
"$PROJECT_DIR/scripts/export_powerbi_snapshot.sh"

echo "5/7 Building the compact cloud snapshot"
PYTHONPATH="/Users/hoangyugi001/.cache/codex-runtimes/codex-primary-runtime/dependencies/python" \
  "$PYTHON_BIN" "$PROJECT_DIR/scripts/build_powerbi_cloud_snapshot.py"

echo "6/7 Building the Power BI cloud workbook"
"$NODE_BIN" "$PROJECT_DIR/scripts/build_powerbi_cloud_workbook.mjs"

echo "7/7 Validating Week 3 outputs"
"$PROJECT_DIR/scripts/validate_week3.sh"

echo "Week 3 macOS cloud package completed."
echo "Next: upload the workbook to the existing OneDrive/SharePoint path and refresh the semantic model."
echo "Guide: docs/20_HuongDanChayTuan3_macOS_PostgreSQL_PowerBI.md"
