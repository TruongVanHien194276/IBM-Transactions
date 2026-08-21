#!/usr/bin/env python3
"""Create the compact, deterministic snapshot used by Power BI Service."""

from __future__ import annotations

import csv
import shutil
from pathlib import Path


PROJECT_DIR = Path("/Users/hoangyugi001/Documents/Coder/IBM Transactions")
SOURCE_DIR = PROJECT_DIR / "powerbi/data_snapshot"
TARGET_DIR = PROJECT_DIR / "powerbi/cloud/data_snapshot_compact"

BANK_LIMIT = 1_000
ACCOUNT_LIMIT = 5_000


def read_csv(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open("r", encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream)
        if reader.fieldnames is None:
            raise ValueError(f"CSV has no header: {path}")
        return list(reader.fieldnames), list(reader)


def write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def numeric(row: dict[str, str], column: str) -> float:
    value = row.get(column, "")
    if value in {"", None}:
        return 0.0
    return float(value)


def build() -> None:
    if not SOURCE_DIR.is_dir():
        raise FileNotFoundError(
            f"Missing {SOURCE_DIR}. Run scripts/export_powerbi_snapshot.sh first."
        )

    TARGET_DIR.mkdir(parents=True, exist_ok=True)

    bank_fields, bank_rows = read_csv(SOURCE_DIR / "fact_bank_activity.csv")
    compact_bank_rows = sorted(
        bank_rows,
        key=lambda row: (
            -numeric(row, "total_participations"),
            -numeric(row, "laundering_participations"),
            int(row["bank_key"]),
        ),
    )[:BANK_LIMIT]
    write_csv(TARGET_DIR / "fact_bank_activity.csv", bank_fields, compact_bank_rows)

    account_fields, account_rows = read_csv(
        SOURCE_DIR / "fact_aml_account_risk.csv"
    )
    compact_account_rows = sorted(
        account_rows,
        key=lambda row: (
            -numeric(row, "laundering_participations"),
            -numeric(row, "laundering_sent_count"),
            int(row["account_key"]),
        ),
    )[:ACCOUNT_LIMIT]
    write_csv(
        TARGET_DIR / "fact_aml_account_risk.csv",
        account_fields,
        compact_account_rows,
    )

    referenced_bank_keys = {
        row["bank_key"] for row in compact_bank_rows + compact_account_rows
    }
    dim_bank_fields, dim_bank_rows = read_csv(SOURCE_DIR / "dim_bank.csv")
    compact_dim_bank_rows = [
        row for row in dim_bank_rows if row["bank_key"] in referenced_bank_keys
    ]
    compact_dim_bank_rows.sort(key=lambda row: int(row["bank_key"]))
    write_csv(TARGET_DIR / "dim_bank.csv", dim_bank_fields, compact_dim_bank_rows)

    compacted_files = {
        "dim_bank.csv",
        "fact_bank_activity.csv",
        "fact_aml_account_risk.csv",
    }
    for source_path in sorted(SOURCE_DIR.glob("*.csv")):
        if source_path.name not in compacted_files:
            shutil.copy2(source_path, TARGET_DIR / source_path.name)

    target_files = sorted(TARGET_DIR.glob("*.csv"))
    if len(target_files) != 16:
        raise RuntimeError(
            f"Expected 16 compact CSV files, found {len(target_files)}"
        )

    print(f"Created {len(target_files)} compact CSV files in {TARGET_DIR}")
    print(
        "Rows retained: "
        f"bank activity={len(compact_bank_rows):,}, "
        f"AML account risk={len(compact_account_rows):,}, "
        f"bank dimension={len(compact_dim_bank_rows):,}"
    )


if __name__ == "__main__":
    build()
