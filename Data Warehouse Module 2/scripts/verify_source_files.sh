#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/Users/hoangyugi001/Documents/Coder/IBM Transactions"
RAW_DIR="$PROJECT_DIR/data/raw"
DOCS_DIR="$PROJECT_DIR/docs"
MANIFEST="$DOCS_DIR/source_manifest.csv"

mkdir -p "$DOCS_DIR"

files=(
  "HI-Medium_Trans.csv"
  "HI-Medium_accounts.csv"
  "HI-Medium_Patterns.txt"
)

expected_bytes=(
  "3031783420"
  "145008642"
  "2279574"
)

printf 'file_name,expected_bytes,actual_bytes,line_count,sha256,status\n' > "$MANIFEST"

for index in "${!files[@]}"; do
  file="${files[$index]}"
  expected="${expected_bytes[$index]}"
  path="$RAW_DIR/$file"

  if [[ ! -f "$path" ]]; then
    printf '%s,%s,0,0,,MISSING\n' "$file" "$expected" >> "$MANIFEST"
    echo "Thiếu file: $file" >&2
    continue
  fi

  actual="$(stat -f '%z' "$path")"
  lines="$(wc -l < "$path" | tr -d ' ')"
  digest="$(openssl dgst -sha256 "$path" | awk '{print $NF}')"

  if [[ "$actual" == "$expected" ]]; then
    status="OK"
  else
    status="SIZE_MISMATCH"
  fi

  printf '%s,%s,%s,%s,%s,%s\n' "$file" "$expected" "$actual" "$lines" "$digest" "$status" >> "$MANIFEST"
done

column -s, -t "$MANIFEST"

