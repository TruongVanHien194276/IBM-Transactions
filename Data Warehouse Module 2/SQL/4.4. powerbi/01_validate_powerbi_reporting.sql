/*
Validation cho lớp Power BI reporting
Mọi truy vấn bên dưới phải trả về trạng thái PASS hoặc số lỗi bằng 0.
*/

SELECT
    CASE WHEN count(*) = 16 THEN 'PASS' ELSE 'FAIL' END AS object_count_status,
    count(*) AS pbi_view_count
FROM information_schema.views
WHERE table_schema = 'pbi';

SELECT
    CASE
        WHEN k.transaction_count = 31898238
         AND k.laundering_count = 35230
         AND k.cross_bank_count = 29092624
         AND k.cross_currency_count = 485144
         AND k.self_transfer_count = 2561860
        THEN 'PASS'
        ELSE 'FAIL'
    END AS kpi_status,
    k.*
FROM pbi.kpi_overview k;

SELECT *
FROM
(
    SELECT 'dim_date' AS object_name, count(*) AS row_count FROM pbi.dim_date
    UNION ALL
    SELECT 'dim_payment_currency', count(*) FROM pbi.dim_payment_currency
    UNION ALL
    SELECT 'dim_receiving_currency', count(*) FROM pbi.dim_receiving_currency
    UNION ALL
    SELECT 'dim_payment_format', count(*) FROM pbi.dim_payment_format
    UNION ALL
    SELECT 'dim_bank', count(*) FROM pbi.dim_bank
    UNION ALL
    SELECT 'dim_pattern_type', count(*) FROM pbi.dim_pattern_type
    UNION ALL
    SELECT 'kpi_overview', count(*) FROM pbi.kpi_overview
    UNION ALL
    SELECT 'fact_daily_transaction', count(*) FROM pbi.fact_daily_transaction
    UNION ALL
    SELECT 'fact_aml_payment_format', count(*) FROM pbi.fact_aml_payment_format
    UNION ALL
    SELECT 'fact_bank_activity', count(*) FROM pbi.fact_bank_activity
    UNION ALL
    SELECT 'fact_currency_flow', count(*) FROM pbi.fact_currency_flow
    UNION ALL
    SELECT 'fact_pattern_summary', count(*) FROM pbi.fact_pattern_summary
    UNION ALL
    SELECT 'fact_aml_account_risk', count(*) FROM pbi.fact_aml_account_risk
    UNION ALL
    SELECT 'etl_batch_monitor', count(*) FROM pbi.etl_batch_monitor
    UNION ALL
    SELECT 'etl_validation_result', count(*) FROM pbi.etl_validation_result
    UNION ALL
    SELECT 'data_quality_overview', count(*) FROM pbi.data_quality_overview
) c
ORDER BY object_name;

SELECT 'duplicate_date_key' AS check_name, count(*) AS error_count
FROM
(
    SELECT date_key FROM pbi.dim_date
    GROUP BY date_key HAVING count(*) > 1
) x
UNION ALL
SELECT 'duplicate_daily_grain', count(*)
FROM
(
    SELECT date_key, payment_currency_key, payment_format_key
    FROM pbi.fact_daily_transaction
    GROUP BY date_key, payment_currency_key, payment_format_key
    HAVING count(*) > 1
) x
UNION ALL
SELECT 'daily_missing_date', count(*)
FROM pbi.fact_daily_transaction f
LEFT JOIN pbi.dim_date d ON d.date_key = f.date_key
WHERE d.date_key IS NULL
UNION ALL
SELECT 'daily_missing_payment_currency', count(*)
FROM pbi.fact_daily_transaction f
LEFT JOIN pbi.dim_payment_currency c
       ON c.payment_currency_key = f.payment_currency_key
WHERE c.payment_currency_key IS NULL
UNION ALL
SELECT 'daily_missing_payment_format', count(*)
FROM pbi.fact_daily_transaction f
LEFT JOIN pbi.dim_payment_format p
       ON p.payment_format_key = f.payment_format_key
WHERE p.payment_format_key IS NULL
UNION ALL
SELECT 'currency_flow_missing_payment_currency', count(*)
FROM pbi.fact_currency_flow f
LEFT JOIN pbi.dim_payment_currency c
       ON c.payment_currency_key = f.payment_currency_key
WHERE c.payment_currency_key IS NULL
UNION ALL
SELECT 'currency_flow_missing_receiving_currency', count(*)
FROM pbi.fact_currency_flow f
LEFT JOIN pbi.dim_receiving_currency c
       ON c.receiving_currency_key = f.receiving_currency_key
WHERE c.receiving_currency_key IS NULL
UNION ALL
SELECT 'bank_activity_missing_bank', count(*)
FROM pbi.fact_bank_activity f
LEFT JOIN pbi.dim_bank b ON b.bank_key = f.bank_key
WHERE b.bank_key IS NULL
UNION ALL
SELECT 'account_risk_missing_bank', count(*)
FROM pbi.fact_aml_account_risk f
LEFT JOIN pbi.dim_bank b ON b.bank_key = f.bank_key
WHERE b.bank_key IS NULL
UNION ALL
SELECT 'pattern_missing_type', count(*)
FROM pbi.fact_pattern_summary f
LEFT JOIN pbi.dim_pattern_type p
       ON p.pattern_type_key = f.pattern_type_key
WHERE p.pattern_type_key IS NULL;

SELECT *
FROM pbi.data_quality_overview;
