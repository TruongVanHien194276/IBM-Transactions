#!/bin/zsh
set -euo pipefail

PROJECT_DIR="/Users/hoangyugi001/Documents/Coder/IBM Transactions"
DATABASE_NAME="aml_source"
LOG_DIR="$PROJECT_DIR/logs"
RUN_ID=$(date '+%Y%m%d_%H%M%S')
LOG_FILE="$LOG_DIR/week2_dw_${RUN_ID}.log"

mkdir -p "$LOG_DIR"
cd "$PROJECT_DIR"

SQL_FILES=(
    "sql/03_dw/00_prepare_dw_environment.sql"
    "sql/03_dw/01_create_dw_tables.sql"
    "sql/03_dw/02_create_etl_procedures.sql"
    "sql/03_dw/03_run_full_etl.sql"
    "sql/03_dw/04_create_dw_indexes.sql"
    "sql/03_dw/05_create_data_marts.sql"
    "sql/03_dw/06_validate_dw.sql"
)

{
    echo "Week 2 PostgreSQL DW started: $(date)"
    echo "Database: $DATABASE_NAME"

    pg_isready -h localhost -p 5432

    for sql_file in "${SQL_FILES[@]}"; do
        echo "Running $sql_file"
        psql -v ON_ERROR_STOP=1 -d "$DATABASE_NAME" -f "$sql_file"
    done

    echo "Week 2 PostgreSQL DW completed: $(date)"
} 2>&1 | tee "$LOG_FILE"

echo "Log saved to: $LOG_FILE"

