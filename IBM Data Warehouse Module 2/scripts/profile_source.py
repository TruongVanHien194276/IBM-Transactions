#!/usr/bin/env python3
"""Materialize and profile the IBM AML HI-Medium source with DuckDB."""

from __future__ import annotations

import argparse
import csv
import json
from datetime import date, datetime
from decimal import Decimal
from pathlib import Path
from typing import Any

import duckdb

PROJECT_DIR = Path("/Users/hoangyugi001/Documents/Coder/IBM Transactions")
RAW_DIR = PROJECT_DIR / "data/raw"
PROCESSED_DIR = PROJECT_DIR / "data/processed"
PROFILE_DIR = PROJECT_DIR / "data/profile"
DOCS_DIR = PROJECT_DIR / "docs"
DB_PATH = PROFILE_DIR / "ibm_aml_profile.duckdb"

TRANSACTION_FILE = RAW_DIR / "HI-Medium_Trans.csv"
ACCOUNT_FILE = RAW_DIR / "HI-Medium_accounts.csv"
PATTERN_FILE = PROCESSED_DIR / "HI-Medium_PatternTransactions.csv"

EXPECTED_BYTES = {
    TRANSACTION_FILE.name: 3_031_783_420,
    ACCOUNT_FILE.name: 145_008_642,
    "HI-Medium_Patterns.txt": 2_279_574,
}


def json_safe(value: Any) -> Any:
    if isinstance(value, datetime):
        return value.isoformat(sep=" ")
    if isinstance(value, date):
        return value.isoformat()
    if isinstance(value, Decimal):
        return str(value)
    return value


def scalar(connection: duckdb.DuckDBPyConnection, query: str) -> Any:
    return connection.execute(query).fetchone()[0]


def rows_as_dicts(connection: duckdb.DuckDBPyConnection, query: str) -> list[dict[str, Any]]:
    result = connection.execute(query)
    columns = [item[0] for item in result.description]
    return [dict(zip(columns, row)) for row in result.fetchall()]


def write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def markdown_table(rows: list[dict[str, Any]], limit: int | None = None) -> str:
    visible = rows if limit is None else rows[:limit]
    if not visible:
        return "_Không có dữ liệu._"
    headers = list(visible[0].keys())
    output = [
        "| " + " | ".join(headers) + " |",
        "| " + " | ".join(["---"] * len(headers)) + " |",
    ]
    for row in visible:
        output.append(
            "| "
            + " | ".join(str(json_safe(row.get(header, ""))).replace("|", "\\|") for header in headers)
            + " |"
        )
    return "\n".join(output)


def validate_files() -> None:
    required = [TRANSACTION_FILE, ACCOUNT_FILE, RAW_DIR / "HI-Medium_Patterns.txt"]
    problems: list[str] = []
    for path in required:
        if not path.exists():
            problems.append(f"Missing: {path}")
            continue
        expected = EXPECTED_BYTES[path.name]
        actual = path.stat().st_size
        if actual != expected:
            problems.append(f"Incomplete: {path.name}: expected {expected}, got {actual}")
    if problems:
        raise SystemExit("\n".join(problems))
    if not PATTERN_FILE.exists():
        raise SystemExit("Run scripts/parse_patterns.py before profiling")


def materialize(connection: duckdb.DuckDBPyConnection, rebuild: bool) -> None:
    existing = {
        row[0]
        for row in connection.execute(
            "SELECT table_name FROM information_schema.tables WHERE table_schema = 'main'"
        ).fetchall()
    }

    if rebuild:
        connection.execute("DROP TABLE IF EXISTS source_transaction")
        connection.execute("DROP TABLE IF EXISTS source_account")
        connection.execute("DROP TABLE IF EXISTS source_pattern_transaction")
        existing.clear()

    if "source_transaction" not in existing:
        print("Materializing source_transaction ...", flush=True)
        connection.execute(
            """
            CREATE TABLE source_transaction AS
            SELECT
                row_number() OVER ()::BIGINT AS source_row_id,
                trim("Timestamp") AS raw_timestamp,
                try_strptime(trim("Timestamp"), '%Y/%m/%d %H:%M') AS transaction_timestamp,
                trim("From Bank") AS raw_from_bank_id,
                cast(try_cast(trim("From Bank") AS UBIGINT) AS VARCHAR) AS from_bank_id,
                upper(trim("Account")) AS from_account_id,
                trim("To Bank") AS raw_to_bank_id,
                cast(try_cast(trim("To Bank") AS UBIGINT) AS VARCHAR) AS to_bank_id,
                upper(trim("Account_1")) AS to_account_id,
                try_cast(trim("Amount Received") AS DECIMAL(24, 8)) AS amount_received,
                trim("Receiving Currency") AS receiving_currency,
                try_cast(trim("Amount Paid") AS DECIMAL(24, 8)) AS amount_paid,
                trim("Payment Currency") AS payment_currency,
                trim("Payment Format") AS payment_format,
                try_cast(trim("Is Laundering") AS UTINYINT) AS is_laundering
            FROM read_csv_auto(?, header = true, all_varchar = true, parallel = true)
            """,
            [str(TRANSACTION_FILE)],
        )

    if "source_account" not in existing:
        print("Materializing source_account ...", flush=True)
        connection.execute(
            """
            CREATE TABLE source_account AS
            SELECT
                row_number() OVER ()::BIGINT AS source_account_row_id,
                trim("Bank Name") AS bank_name,
                trim("Bank ID") AS raw_bank_id,
                cast(try_cast(trim("Bank ID") AS UBIGINT) AS VARCHAR) AS bank_id,
                upper(trim("Account Number")) AS account_number,
                upper(trim("Entity ID")) AS entity_id,
                trim("Entity Name") AS entity_name
            FROM read_csv_auto(?, header = true, all_varchar = true, parallel = true)
            """,
            [str(ACCOUNT_FILE)],
        )

    if "source_pattern_transaction" not in existing:
        print("Materializing source_pattern_transaction ...", flush=True)
        connection.execute(
            """
            CREATE TABLE source_pattern_transaction AS
            SELECT
                try_cast("PatternAttemptID" AS BIGINT) AS pattern_attempt_id,
                trim("PatternType") AS pattern_type,
                trim("PatternDescription") AS pattern_description,
                try_cast("PatternSequence" AS INTEGER) AS pattern_sequence,
                try_strptime(trim("TransactionTimestamp"), '%Y/%m/%d %H:%M') AS transaction_timestamp,
                cast(try_cast(trim("FromBankID") AS UBIGINT) AS VARCHAR) AS from_bank_id,
                upper(trim("FromAccountID")) AS from_account_id,
                cast(try_cast(trim("ToBankID") AS UBIGINT) AS VARCHAR) AS to_bank_id,
                upper(trim("ToAccountID")) AS to_account_id,
                try_cast("AmountReceived" AS DECIMAL(24, 8)) AS amount_received,
                trim("ReceivingCurrency") AS receiving_currency,
                try_cast("AmountPaid" AS DECIMAL(24, 8)) AS amount_paid,
                trim("PaymentCurrency") AS payment_currency,
                trim("PaymentFormat") AS payment_format,
                try_cast("IsLaundering" AS UTINYINT) AS is_laundering
            FROM read_csv_auto(?, header = true, all_varchar = true)
            """,
            [str(PATTERN_FILE)],
        )


def profile(connection: duckdb.DuckDBPyConnection) -> None:
    print("Computing summary metrics ...", flush=True)
    summary_rows = rows_as_dicts(
        connection,
        """
        WITH transaction_stats AS (
            SELECT
                count(*) AS transaction_count,
                min(transaction_timestamp) AS min_timestamp,
                max(transaction_timestamp) AS max_timestamp,
                count(*) FILTER (WHERE is_laundering = 1) AS laundering_count,
                count(*) FILTER (WHERE from_bank_id <> to_bank_id) AS cross_bank_count,
                count(*) FILTER (WHERE from_bank_id = to_bank_id) AS same_bank_count,
                count(*) FILTER (WHERE payment_currency <> receiving_currency) AS cross_currency_count,
                count(*) FILTER (WHERE payment_currency = receiving_currency) AS same_currency_count,
                count(*) FILTER (
                    WHERE from_bank_id = to_bank_id AND from_account_id = to_account_id
                ) AS self_transfer_count
            FROM source_transaction
        ), account_stats AS (
            SELECT
                count(*) AS account_master_rows,
                count(DISTINCT (bank_id, account_number)) AS account_business_keys,
                count(DISTINCT bank_id) AS bank_master_count,
                count(DISTINCT entity_id) AS entity_count
            FROM source_account
        ), pattern_stats AS (
            SELECT
                count(*) AS pattern_transaction_count,
                count(DISTINCT pattern_attempt_id) AS pattern_attempt_count,
                count(DISTINCT pattern_type) AS pattern_type_count
            FROM source_pattern_transaction
        )
        SELECT * FROM transaction_stats, account_stats, pattern_stats
        """,
    )
    summary = summary_rows[0]
    summary["laundering_rate_percent"] = round(
        summary["laundering_count"] * 100.0 / summary["transaction_count"], 6
    )

    print("Computing active bank/account coverage ...", flush=True)
    coverage = rows_as_dicts(
        connection,
        """
        WITH active_accounts AS (
            SELECT from_bank_id AS bank_id, from_account_id AS account_number
            FROM source_transaction
            UNION
            SELECT to_bank_id AS bank_id, to_account_id AS account_number
            FROM source_transaction
        )
        SELECT
            count(*) AS active_account_count,
            count(DISTINCT aa.bank_id) AS active_bank_count,
            count(*) FILTER (WHERE sa.source_account_row_id IS NULL) AS active_accounts_missing_master
        FROM active_accounts aa
        LEFT JOIN source_account sa
          ON sa.bank_id = aa.bank_id
         AND sa.account_number = aa.account_number
        """,
    )[0]
    summary.update(coverage)

    print("Computing data-quality metrics ...", flush=True)
    quality = rows_as_dicts(
        connection,
        """
        SELECT
            count(*) FILTER (WHERE transaction_timestamp IS NULL) AS invalid_timestamp_count,
            count(*) FILTER (WHERE from_bank_id IS NULL OR from_bank_id = '') AS missing_from_bank_count,
            count(*) FILTER (WHERE from_account_id IS NULL OR from_account_id = '') AS missing_from_account_count,
            count(*) FILTER (WHERE to_bank_id IS NULL OR to_bank_id = '') AS missing_to_bank_count,
            count(*) FILTER (WHERE to_account_id IS NULL OR to_account_id = '') AS missing_to_account_count,
            count(*) FILTER (WHERE amount_paid IS NULL) AS invalid_amount_paid_count,
            count(*) FILTER (WHERE amount_received IS NULL) AS invalid_amount_received_count,
            count(*) FILTER (WHERE amount_paid <= 0) AS nonpositive_amount_paid_count,
            count(*) FILTER (WHERE amount_received <= 0) AS nonpositive_amount_received_count,
            count(*) FILTER (WHERE payment_currency IS NULL OR payment_currency = '') AS missing_payment_currency_count,
            count(*) FILTER (WHERE receiving_currency IS NULL OR receiving_currency = '') AS missing_receiving_currency_count,
            count(*) FILTER (WHERE payment_format IS NULL OR payment_format = '') AS missing_payment_format_count,
            count(*) FILTER (WHERE is_laundering NOT IN (0, 1) OR is_laundering IS NULL) AS invalid_laundering_label_count,
            count(*) FILTER (
                WHERE payment_currency = receiving_currency
                  AND amount_paid <> amount_received
            ) AS same_currency_amount_mismatch_count
        FROM source_transaction
        """,
    )[0]

    print("Computing distributions ...", flush=True)
    currency_rows = rows_as_dicts(
        connection,
        """
        SELECT
            payment_currency,
            receiving_currency,
            count(*) AS transaction_count,
            count(*) FILTER (WHERE is_laundering = 1) AS laundering_count,
            sum(amount_paid) AS total_amount_paid,
            sum(amount_received) AS total_amount_received
        FROM source_transaction
        GROUP BY payment_currency, receiving_currency
        ORDER BY transaction_count DESC
        """,
    )
    payment_rows = rows_as_dicts(
        connection,
        """
        SELECT
            payment_format,
            count(*) AS transaction_count,
            count(*) FILTER (WHERE is_laundering = 1) AS laundering_count,
            round(100.0 * count(*) FILTER (WHERE is_laundering = 1) / count(*), 6) AS laundering_rate_percent
        FROM source_transaction
        GROUP BY payment_format
        ORDER BY transaction_count DESC
        """,
    )
    daily_rows = rows_as_dicts(
        connection,
        """
        SELECT
            cast(transaction_timestamp AS DATE) AS transaction_date,
            count(*) AS transaction_count,
            count(*) FILTER (WHERE is_laundering = 1) AS laundering_count,
            count(DISTINCT from_bank_id) AS sender_bank_count,
            count(DISTINCT to_bank_id) AS receiver_bank_count
        FROM source_transaction
        GROUP BY cast(transaction_timestamp AS DATE)
        ORDER BY transaction_date
        """,
    )
    pattern_rows = rows_as_dicts(
        connection,
        """
        SELECT
            pattern_type,
            count(DISTINCT pattern_attempt_id) AS attempt_count,
            count(*) AS transaction_count,
            min(pattern_sequence) AS min_sequence,
            max(pattern_sequence) AS max_sequence
        FROM source_pattern_transaction
        GROUP BY pattern_type
        ORDER BY attempt_count DESC, pattern_type
        """,
    )
    top_bank_rows = rows_as_dicts(
        connection,
        """
        WITH bank_activity AS (
            SELECT from_bank_id AS bank_id, count(*) AS sent_count, 0::BIGINT AS received_count
            FROM source_transaction GROUP BY from_bank_id
            UNION ALL
            SELECT to_bank_id AS bank_id, 0::BIGINT AS sent_count, count(*) AS received_count
            FROM source_transaction GROUP BY to_bank_id
        )
        , bank_master AS (
            SELECT bank_id, max(bank_name) AS bank_name
            FROM source_account
            GROUP BY bank_id
        )
        SELECT
            ba.bank_id,
            max(bm.bank_name) AS bank_name,
            sum(sent_count) AS sent_count,
            sum(received_count) AS received_count,
            sum(sent_count + received_count) AS total_participations
        FROM bank_activity ba
        LEFT JOIN bank_master bm ON bm.bank_id = ba.bank_id
        GROUP BY ba.bank_id
        ORDER BY total_participations DESC
        LIMIT 20
        """,
    )

    PROFILE_DIR.mkdir(parents=True, exist_ok=True)
    DOCS_DIR.mkdir(parents=True, exist_ok=True)

    output = {
        "dataset": "IBM AML HI-Medium",
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "summary": {key: json_safe(value) for key, value in summary.items()},
        "data_quality": {key: json_safe(value) for key, value in quality.items()},
        "currency_pairs": [{key: json_safe(value) for key, value in row.items()} for row in currency_rows],
        "payment_formats": [{key: json_safe(value) for key, value in row.items()} for row in payment_rows],
        "daily": [{key: json_safe(value) for key, value in row.items()} for row in daily_rows],
        "patterns": [{key: json_safe(value) for key, value in row.items()} for row in pattern_rows],
        "top_banks": [{key: json_safe(value) for key, value in row.items()} for row in top_bank_rows],
    }

    (PROFILE_DIR / "source_profile.json").write_text(
        json.dumps(output, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    write_csv(PROFILE_DIR / "currency_pairs.csv", currency_rows)
    write_csv(PROFILE_DIR / "payment_formats.csv", payment_rows)
    write_csv(PROFILE_DIR / "daily_transactions.csv", daily_rows)
    write_csv(PROFILE_DIR / "pattern_types.csv", pattern_rows)
    write_csv(PROFILE_DIR / "top_banks.csv", top_bank_rows)

    report = f"""# Báo cáo khảo sát dữ liệu nguồn – IBM AML HI-Medium

Thời điểm tạo: {output['generated_at']}

## 1. Thống kê tổng quan

{markdown_table([{'metric': key, 'value': json_safe(value)} for key, value in summary.items()])}

## 2. Chất lượng dữ liệu

{markdown_table([{'metric': key, 'value': json_safe(value)} for key, value in quality.items()])}

## 3. Phương thức thanh toán

{markdown_table(payment_rows)}

## 4. Hoạt động theo ngày

{markdown_table(daily_rows)}

## 5. Các mẫu rửa tiền

{markdown_table(pattern_rows)}

## 6. Top ngân hàng theo số lượt tham gia giao dịch

{markdown_table(top_bank_rows)}

## 7. Các cặp tiền tệ phổ biến

{markdown_table(currency_rows, limit=30)}

## 8. Kết luận kỹ thuật

- Bank ID trong transaction có thể có số 0 ở đầu; khi liên kết với account master cần chuẩn hóa về giá trị số rồi chuyển lại thành chuỗi.
- Khóa nghiệp vụ tài khoản phải là `(BankID đã chuẩn hóa, AccountNumber)`.
- Mọi tổng tiền phải giữ currency trong grain; không cộng trực tiếp nhiều currency.
- `Is Laundering` là ground truth synthetic và cần được tách biệt với alert hoặc prediction trong các giai đoạn sau.
"""
    (DOCS_DIR / "03_BaoCaoKhaoSatNguon.md").write_text(report, encoding="utf-8")
    print(DOCS_DIR / "03_BaoCaoKhaoSatNguon.md")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--rebuild", action="store_true", help="Recreate DuckDB source tables")
    args = parser.parse_args()

    validate_files()
    PROFILE_DIR.mkdir(parents=True, exist_ok=True)
    (PROFILE_DIR / "tmp").mkdir(parents=True, exist_ok=True)

    connection = duckdb.connect(str(DB_PATH))
    connection.execute("SET threads = 6")
    connection.execute("SET memory_limit = '8GB'")
    connection.execute(f"SET temp_directory = '{(PROFILE_DIR / 'tmp').as_posix()}'")
    connection.execute("SET preserve_insertion_order = false")

    materialize(connection, args.rebuild)
    profile(connection)
    connection.close()


if __name__ == "__main__":
    main()
