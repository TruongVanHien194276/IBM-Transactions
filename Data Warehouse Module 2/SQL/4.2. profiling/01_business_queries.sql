/* Các truy vấn nghiệp vụ mẫu cho PostgreSQL / Power BI. */

-- Giao dịch theo ngày.
SELECT
    transaction_timestamp::DATE AS transaction_date,
    count(*) AS transaction_count,
    count(*) FILTER (WHERE is_laundering) AS laundering_count
FROM raw.transactions
GROUP BY transaction_timestamp::DATE
ORDER BY transaction_date;

-- Top 20 ngân hàng gửi.
SELECT
    t.from_bank_id,
    max(b.bank_name) AS bank_name,
    count(*) AS sent_transaction_count
FROM raw.transactions t
LEFT JOIN src.vw_bank b
  ON b.bank_id = t.from_bank_id
GROUP BY t.from_bank_id
ORDER BY sent_transaction_count DESC
LIMIT 20;

-- Không cộng amount của nhiều currency với nhau.
SELECT
    payment_currency,
    count(*) AS transaction_count,
    sum(amount_paid) AS total_amount_paid,
    avg(amount_paid) AS average_amount_paid
FROM raw.transactions
GROUP BY payment_currency
ORDER BY transaction_count DESC;

-- Tỷ lệ AML theo payment format.
SELECT
    payment_format,
    count(*) AS transaction_count,
    count(*) FILTER (WHERE is_laundering) AS laundering_count,
    round(100.0 * count(*) FILTER (WHERE is_laundering) / count(*), 6)
        AS laundering_rate_percent
FROM raw.transactions
GROUP BY payment_format
ORDER BY transaction_count DESC;

-- Mẫu hình AML theo loại pattern.
SELECT
    pattern_type,
    count(DISTINCT pattern_attempt_id) AS attempt_count,
    count(*) AS pattern_transaction_count
FROM raw.laundering_pattern_transaction
GROUP BY pattern_type
ORDER BY pattern_type;
