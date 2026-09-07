/* Bộ reconciliation và kiểm tra nghiệp vụ sau transform */

SELECT *
FROM etl.load_batch
ORDER BY batch_id DESC
LIMIT 1;

SELECT 'Account' AS source_object, count(*) AS row_count FROM raw.account
UNION ALL
SELECT 'Transaction', count(*) FROM raw.transactions
UNION ALL
SELECT 'PatternTransaction', count(*) FROM raw.laundering_pattern_transaction
UNION ALL
SELECT 'RejectedRow', count(*) FROM raw.rejected_row;

SELECT
    min(transaction_timestamp) AS min_timestamp,
    max(transaction_timestamp) AS max_timestamp
FROM raw.transactions;

SELECT is_laundering, count(*) AS transaction_count
FROM raw.transactions
GROUP BY is_laundering
ORDER BY is_laundering;

SELECT
    payment_format,
    count(*) AS transaction_count,
    count(*) FILTER (WHERE is_laundering) AS laundering_count,
    round(100.0 * count(*) FILTER (WHERE is_laundering) / count(*), 6) AS laundering_rate_pct
FROM raw.transactions
GROUP BY payment_format
ORDER BY transaction_count DESC;

WITH active_account AS
(
    SELECT from_bank_id AS bank_id, from_account_id AS account_number
    FROM raw.transactions
    UNION
    SELECT to_bank_id, to_account_id
    FROM raw.transactions
)
SELECT
    count(*) AS active_account_count,
    count(*) FILTER (WHERE a.source_account_id IS NULL) AS missing_master_count
FROM active_account x
LEFT JOIN raw.account a
  ON a.bank_id = x.bank_id
 AND a.account_number = x.account_number;

SELECT
    count(*) FILTER (WHERE amount_paid <= 0) AS non_positive_paid,
    count(*) FILTER (WHERE amount_received <= 0) AS non_positive_received,
    count(*) FILTER
    (
        WHERE from_bank_id = to_bank_id
          AND from_account_id = to_account_id
    ) AS self_transfer_count,
    count(*) FILTER (WHERE payment_currency <> receiving_currency) AS cross_currency_count,
    count(*) FILTER
    (
        WHERE payment_currency = receiving_currency
          AND amount_paid <> amount_received
    ) AS same_currency_amount_mismatch
FROM raw.transactions;

SELECT
    count(*) FILTER (WHERE from_bank_id <> to_bank_id) AS cross_bank_count,
    count(*) FILTER (WHERE from_bank_id = to_bank_id) AS same_bank_count,
    count(*) FILTER (WHERE is_laundering) AS laundering_count,
    round(100.0 * count(*) FILTER (WHERE is_laundering) / count(*), 6) AS laundering_rate_pct
FROM raw.transactions;

SELECT
    pattern_type,
    count(DISTINCT pattern_attempt_id) AS attempt_count,
    count(*) AS pattern_transaction_count
FROM raw.laundering_pattern_transaction
GROUP BY pattern_type
ORDER BY pattern_type;
