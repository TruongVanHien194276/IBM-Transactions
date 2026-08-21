/*
Tuần 4 - Bằng chứng hiệu năng

Chạy riêng trong DBeaver bằng Execute SQL Script. Các câu lệnh chỉ đọc và dùng
EXPLAIN ANALYZE để ghi nhận execution time/buffer của truy vấn báo cáo.
*/

\set ON_ERROR_STOP on
\pset pager off
\timing on

ANALYZE dw.fact_transaction;
ANALYZE mart.mv_kpi_overview;
ANALYZE mart.mv_daily_transaction;
ANALYZE mart.mv_aml_by_payment_format;

-- 1. KPI tổng quan: một dòng đã được materialize.
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT *
FROM pbi.kpi_overview;

-- 2. Xu hướng ngày: chỉ đọc bảng tổng hợp, không quét fact 31,8 triệu dòng.
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    d.full_date,
    sum(f.transaction_count) AS transaction_count,
    sum(f.laundering_count) AS laundering_count
FROM pbi.fact_daily_transaction f
JOIN pbi.dim_date d ON d.date_key = f.date_key
GROUP BY d.full_date
ORDER BY d.full_date;

-- 3. AML theo payment format.
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    p.payment_format,
    f.transaction_count,
    f.laundering_count,
    f.laundering_rate_percent
FROM pbi.fact_aml_payment_format f
JOIN pbi.dim_payment_format p
  ON p.payment_format_key = f.payment_format_key
ORDER BY f.laundering_count DESC;

-- 4. Partial index hỗ trợ truy vấn tập laundering nhỏ.
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT count(*)
FROM dw.fact_transaction
WHERE is_laundering;

\timing off
