#!/usr/bin/env python3
"""Parse IBM AML pattern text into a CSV suitable for PostgreSQL COPY."""

from __future__ import annotations

import csv
from pathlib import Path

PROJECT_DIR = Path("/Users/hoangyugi001/Documents/Coder/IBM Transactions")
INPUT_PATH = PROJECT_DIR / "data/raw/HI-Medium_Patterns.txt"
OUTPUT_DIR = PROJECT_DIR / "data/processed"
OUTPUT_PATH = OUTPUT_DIR / "HI-Medium_PatternTransactions.csv"

HEADER = [
    "PatternAttemptID",
    "PatternType",
    "PatternDescription",
    "PatternSequence",
    "TransactionTimestamp",
    "FromBankID",
    "FromAccountID",
    "ToBankID",
    "ToAccountID",
    "AmountReceived",
    "ReceivingCurrency",
    "AmountPaid",
    "PaymentCurrency",
    "PaymentFormat",
    "IsLaundering",
]


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    attempt_id = 0
    sequence = 0
    description = ""
    pattern_type = ""
    transaction_count = 0

    with INPUT_PATH.open("r", encoding="utf-8-sig", newline="") as source, OUTPUT_PATH.open(
        "w", encoding="utf-8", newline=""
    ) as target:
        writer = csv.writer(target)
        writer.writerow(HEADER)

        for line_number, raw_line in enumerate(source, start=1):
            line = raw_line.strip()
            if not line:
                continue

            if line.startswith("BEGIN LAUNDERING ATTEMPT - "):
                attempt_id += 1
                sequence = 0
                description = line.removeprefix("BEGIN LAUNDERING ATTEMPT - ").strip()
                pattern_type = description.split(":", 1)[0].strip().upper()
                continue

            if line.startswith("END LAUNDERING ATTEMPT - "):
                description = ""
                pattern_type = ""
                sequence = 0
                continue

            if not description:
                raise ValueError(f"Transaction outside pattern block at line {line_number}")

            fields = next(csv.reader([line]))
            if len(fields) != 11:
                raise ValueError(
                    f"Expected 11 transaction fields at line {line_number}, got {len(fields)}"
                )

            sequence += 1
            transaction_count += 1
            writer.writerow(
                [attempt_id, pattern_type, description, sequence, *fields]
            )

    print(f"Parsed {attempt_id:,} attempts and {transaction_count:,} transactions")
    print(OUTPUT_PATH)


if __name__ == "__main__":
    main()
