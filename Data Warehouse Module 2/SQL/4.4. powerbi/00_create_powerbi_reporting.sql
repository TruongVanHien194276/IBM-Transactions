/*
Lớp reporting dành riêng cho Power BI
Database: aml_source
Kiến trúc: mart -> pbi -> snapshot -> workbook cloud -> Power BI Service

Mục tiêu:
- Chỉ công bố các bảng/view cần cho báo cáo
- Không cho tài khoản Power BI quyền ghi vào raw/stg/dw/mart
- Giữ grain và quy tắc tiền tệ của Data Warehouse 
- Tạo tên bảng/cột ổn định để DAX và visual không phụ thuộc bảng nguồn
*/

BEGIN;

CREATE SCHEMA IF NOT EXISTS pbi;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'powerbi_readonly') THEN
        CREATE ROLE powerbi_readonly NOLOGIN;
    END IF;
END
$$;

COMMENT ON SCHEMA pbi IS
    'Presentation layer for IBM AML Power BI reports. Read-only for Power BI users.';

CREATE OR REPLACE VIEW pbi.dim_date AS
SELECT
    date_key,
    full_date,
    year_number,
    quarter_number,
    ('Q' || quarter_number::TEXT) AS quarter_label,
    month_number,
    month_name,
    to_char(full_date, 'YYYY-MM') AS year_month,
    (year_number::INTEGER * 100 + month_number::INTEGER) AS year_month_sort,
    week_of_year,
    day_of_month,
    day_of_week,
    day_name,
    is_weekend
FROM dw.dim_date
WHERE date_key <> -1;

CREATE OR REPLACE VIEW pbi.dim_payment_currency AS
SELECT
    currency_key AS payment_currency_key,
    currency_name AS payment_currency
FROM dw.dim_currency
WHERE currency_key <> -1;

CREATE OR REPLACE VIEW pbi.dim_receiving_currency AS
SELECT
    currency_key AS receiving_currency_key,
    currency_name AS receiving_currency
FROM dw.dim_currency
WHERE currency_key <> -1;

CREATE OR REPLACE VIEW pbi.dim_payment_format AS
SELECT
    payment_format_key,
    payment_format
FROM dw.dim_payment_format
WHERE payment_format_key <> -1;

CREATE OR REPLACE VIEW pbi.dim_bank AS
SELECT
    bank_key,
    bank_id,
    bank_name
FROM dw.dim_bank
WHERE bank_key <> -1;

CREATE OR REPLACE VIEW pbi.dim_pattern_type AS
SELECT
    pattern_type_key,
    pattern_type
FROM dw.dim_pattern_type
WHERE pattern_type_key <> -1;

CREATE OR REPLACE VIEW pbi.kpi_overview AS
SELECT
    overview_key,
    transaction_count,
    laundering_count,
    laundering_rate_percent,
    cross_bank_count,
    cross_currency_count,
    self_transfer_count,
    min_transaction_date,
    max_transaction_date
FROM mart.mv_kpi_overview;

CREATE OR REPLACE VIEW pbi.fact_daily_transaction AS
SELECT
    date_key,
    payment_currency_key,
    payment_format_key,
    transaction_count,
    laundering_count,
    laundering_rate_percent,
    total_amount_paid
FROM mart.mv_daily_transaction;

CREATE OR REPLACE VIEW pbi.fact_aml_payment_format AS
SELECT
    payment_format_key,
    transaction_count,
    laundering_count,
    laundering_rate_percent
FROM mart.mv_aml_by_payment_format;

CREATE OR REPLACE VIEW pbi.fact_bank_activity AS
SELECT
    bank_key,
    sent_count,
    received_count,
    total_participations,
    laundering_participations
FROM mart.mv_bank_activity;

CREATE OR REPLACE VIEW pbi.fact_currency_flow AS
SELECT
    payment_currency_key,
    receiving_currency_key,
    transaction_count,
    laundering_count,
    total_amount_paid,
    total_amount_received
FROM mart.mv_currency_flow;

CREATE OR REPLACE VIEW pbi.fact_pattern_summary AS
SELECT
    pattern_type_key,
    attempt_count,
    pattern_transaction_count,
    min_sequence,
    max_sequence
FROM mart.mv_pattern_summary;

CREATE OR REPLACE VIEW pbi.fact_aml_account_risk AS
SELECT
    r.account_key,
    b.bank_key,
    r.account_number,
    r.entity_id,
    r.laundering_sent_count,
    r.laundering_received_count,
    r.laundering_participations
FROM mart.mv_aml_account_risk r
JOIN dw.dim_bank b
  ON b.bank_id = r.bank_id
 AND b.bank_key <> -1;

CREATE OR REPLACE VIEW pbi.etl_batch_monitor AS
SELECT
    dw_batch_id,
    process_name,
    load_type,
    status,
    started_at,
    completed_at,
    round((extract(epoch FROM (completed_at - started_at)) / 60.0)::NUMERIC, 2)
        AS duration_minutes,
    source_low_watermark,
    source_high_watermark,
    pattern_low_watermark,
    pattern_high_watermark,
    transaction_rows_inserted,
    pattern_rows_inserted,
    rejected_rows,
    validation_status,
    error_message
FROM etl.dw_batch;

CREATE OR REPLACE VIEW pbi.etl_validation_result AS
SELECT
    validation_result_id,
    dw_batch_id,
    check_name,
    source_value,
    target_value,
    (target_value - source_value) AS difference_value,
    status,
    details,
    checked_at
FROM etl.dw_validation_result;

CREATE OR REPLACE VIEW pbi.data_quality_overview AS
WITH latest_completed_batch AS
(
    SELECT *
    FROM etl.dw_batch
    WHERE status = 'COMPLETED'
    ORDER BY dw_batch_id DESC
    LIMIT 1
),
latest_full_batch AS
(
    SELECT *
    FROM etl.dw_batch
    WHERE status = 'COMPLETED'
      AND load_type = 'FULL'
    ORDER BY dw_batch_id DESC
    LIMIT 1
)
SELECT
    l.dw_batch_id AS latest_batch_id,
    l.load_type AS latest_load_type,
    l.status AS latest_batch_status,
    l.validation_status AS latest_validation_status,
    l.completed_at AS latest_completed_at,
    l.rejected_rows AS latest_rejected_rows,
    f.dw_batch_id AS validation_batch_id,
    count(v.validation_result_id) AS validation_check_count,
    count(v.validation_result_id) FILTER (WHERE v.status = 'PASSED')
        AS validation_passed_count,
    count(v.validation_result_id) FILTER (WHERE v.status = 'FAILED')
        AS validation_failed_count
FROM latest_completed_batch l
CROSS JOIN latest_full_batch f
LEFT JOIN etl.dw_validation_result v
       ON v.dw_batch_id = f.dw_batch_id
GROUP BY
    l.dw_batch_id, l.load_type, l.status, l.validation_status,
    l.completed_at, l.rejected_rows, f.dw_batch_id;

CREATE OR REPLACE PROCEDURE pbi.refresh_reporting_data()
LANGUAGE plpgsql
AS $$
BEGIN
    CALL mart.refresh_all();
    ANALYZE mart.mv_kpi_overview;
    ANALYZE mart.mv_daily_transaction;
    ANALYZE mart.mv_aml_by_payment_format;
    ANALYZE mart.mv_bank_activity;
    ANALYZE mart.mv_currency_flow;
    ANALYZE mart.mv_pattern_summary;
    ANALYZE mart.mv_aml_account_risk;
    RAISE NOTICE 'Power BI reporting data refreshed successfully';
END;
$$;

GRANT CONNECT ON DATABASE aml_source TO powerbi_readonly;
GRANT USAGE ON SCHEMA pbi TO powerbi_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA pbi TO powerbi_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA pbi
    GRANT SELECT ON TABLES TO powerbi_readonly;

COMMENT ON VIEW pbi.fact_daily_transaction IS
    'Grain: date x payment currency x payment format.';
COMMENT ON VIEW pbi.fact_currency_flow IS
    'Grain: payment currency x receiving currency. Never aggregate amount across currencies without FX conversion.';
COMMENT ON VIEW pbi.fact_bank_activity IS
    'Measures are participations by sender/receiver role, not distinct transaction count.';
COMMENT ON VIEW pbi.fact_aml_account_risk IS
    'One row per account participating in at least one laundering-labelled transaction.';

COMMIT;
