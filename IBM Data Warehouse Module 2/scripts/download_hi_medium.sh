#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/Users/hoangyugi001/Documents/Coder/IBM Transactions"
DATASET="ealtman2019/ibm-transactions-for-anti-money-laundering-aml"
RAW_DIR="$PROJECT_DIR/data/raw"
KAGGLE="$PROJECT_DIR/.venv/bin/kaggle"

mkdir -p "$RAW_DIR"

if [[ ! -x "$KAGGLE" ]]; then
  python3 -m venv "$PROJECT_DIR/.venv"
  "$PROJECT_DIR/.venv/bin/python" -m pip install --upgrade pip kaggle
fi

files=(
  "HI-Medium_Trans.csv"
  "HI-Medium_accounts.csv"
  "HI-Medium_Patterns.txt"
)

for file in "${files[@]}"; do
  if [[ -s "$RAW_DIR/$file" ]]; then
    echo "Đã tồn tại: $file"
  else
    echo "Đang tải: $file"
    "$KAGGLE" datasets download "$DATASET" -f "$file" -p "$RAW_DIR"
  fi
done

"$PROJECT_DIR/scripts/verify_source_files.sh"

