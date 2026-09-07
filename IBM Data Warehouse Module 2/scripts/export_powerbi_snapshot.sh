#!/bin/zsh
set -euo pipefail

PROJECT_DIR="/Users/hoangyugi001/Documents/Coder/IBM Transactions"
EXPORT_DIR="$PROJECT_DIR/powerbi/data_snapshot"

mkdir -p "$EXPORT_DIR"

views=(
  dim_date
  dim_payment_currency
  dim_receiving_currency
  dim_payment_format
  dim_bank
  dim_pattern_type
  kpi_overview
  fact_daily_transaction
  fact_aml_payment_format
  fact_bank_activity
  fact_currency_flow
  fact_pattern_summary
  fact_aml_account_risk
  etl_batch_monitor
  etl_validation_result
  data_quality_overview
)

for view_name in "${views[@]}"; do
  echo "Exporting pbi.$view_name"
  psql -X -v ON_ERROR_STOP=1 -d aml_source \
    -c "\\copy (SELECT * FROM pbi.$view_name) TO '$EXPORT_DIR/$view_name.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8')"
done

echo "Power BI snapshot created at: $EXPORT_DIR"

