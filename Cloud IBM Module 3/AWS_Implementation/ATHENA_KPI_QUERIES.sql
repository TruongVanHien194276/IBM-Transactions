-- IBM AML / Athena KPI starter queries
-- Điều chỉnh tên bảng/cột theo schema thực tế do Glue Crawler tạo.
-- Luôn kiểm tra location và partition trước khi chạy dữ liệu lớn.

-- 1) Data completeness
SELECT
    COUNT(*) AS total_transactions,
    MIN(transaction_timestamp) AS min_timestamp,
    MAX(transaction_timestamp) AS max_timestamp
FROM ibm_aml_curated.fact_transaction;

-- 2) AML count and rate
SELECT
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN is_laundering = 1 THEN 1 ELSE 0 END) AS aml_transactions,
    100.0 * SUM(CASE WHEN is_laundering = 1 THEN 1 ELSE 0 END) / COUNT(*) AS aml_rate_pct
FROM ibm_aml_curated.fact_transaction;

-- 3) Daily profile: dùng để kiểm completeness/source window
SELECT
    txn_date,
    COUNT(*) AS transactions,
    SUM(CASE WHEN is_laundering = 1 THEN 1 ELSE 0 END) AS aml_transactions
FROM ibm_aml_curated.fact_transaction
GROUP BY txn_date
ORDER BY txn_date;

-- 4) AML by payment format
SELECT
    payment_format,
    COUNT(*) AS transactions,
    SUM(CASE WHEN is_laundering = 1 THEN 1 ELSE 0 END) AS aml_transactions,
    100.0 * SUM(CASE WHEN is_laundering = 1 THEN 1 ELSE 0 END) / COUNT(*) AS aml_rate_pct
FROM ibm_aml_curated.fact_transaction
GROUP BY payment_format
ORDER BY aml_transactions DESC;

-- 5) Cross-bank, self-transfer, cross-currency
SELECT
    SUM(CASE WHEN is_cross_bank THEN 1 ELSE 0 END) AS cross_bank_transactions,
    SUM(CASE WHEN is_self_transfer THEN 1 ELSE 0 END) AS self_transfer_transactions,
    SUM(CASE WHEN is_cross_currency THEN 1 ELSE 0 END) AS cross_currency_transactions
FROM ibm_aml_curated.fact_transaction;

-- 6) Pattern summary
SELECT
    pattern_type,
    COUNT(*) AS pattern_transactions,
    COUNT(DISTINCT attempt_id) AS attempts
FROM ibm_aml_curated.bridge_pattern_transaction
GROUP BY pattern_type
ORDER BY pattern_transactions DESC;

-- 7) Partition-aware sample (đổi ngày theo dữ liệu thực tế)
SELECT *
FROM ibm_aml_curated.fact_transaction
WHERE txn_date BETWEEN DATE '2022-09-01' AND DATE '2022-09-07'
LIMIT 100;

-- Không tạo SUM(amount) xuyên nhiều currency nếu chưa có FX normalization.
