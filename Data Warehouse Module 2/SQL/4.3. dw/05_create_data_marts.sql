/*
Materialized views có grain rõ ràng và không cộng tiền khác currency
Power BI nên kết nối mart thay vì quét fact 31,9 triệu dòng cho mọi visual
*/

CREATE MATERIALIZED VIEW IF NOT EXISTS mart.mv_kpi_overview AS
SELECT
    1::SMALLINT AS overview_key,
    count(*) AS transaction_count,
    count(*) FILTER (WHERE is_laundering) AS laundering_count,
    round(100.0 * count(*) FILTER (WHERE is_laundering) / nullif(count(*), 0), 6)
        AS laundering_rate_percent,
    count(*) FILTER (WHERE is_cross_bank) AS cross_bank_count,
    count(*) FILTER (WHERE is_cross_currency) AS cross_currency_count,
    count(*) FILTER (WHERE is_self_transfer) AS self_transfer_count,
    min(d.full_date) AS min_transaction_date,
    max(d.full_date) AS max_transaction_date
FROM dw.fact_transaction f
JOIN dw.dim_date d ON d.date_key = f.date_key;

CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_kpi_overview
    ON mart.mv_kpi_overview (overview_key);

CREATE MATERIALIZED VIEW IF NOT EXISTS mart.mv_daily_transaction AS
SELECT
    d.date_key,
    d.full_date,
    c.currency_key AS payment_currency_key,
    c.currency_name AS payment_currency,
    pf.payment_format_key,
    pf.payment_format,
    count(*) AS transaction_count,
    count(*) FILTER (WHERE f.is_laundering) AS laundering_count,
    round(100.0 * count(*) FILTER (WHERE f.is_laundering) / nullif(count(*), 0), 6)
        AS laundering_rate_percent,
    sum(f.amount_paid) AS total_amount_paid
FROM dw.fact_transaction f
JOIN dw.dim_date d ON d.date_key = f.date_key
JOIN dw.dim_currency c ON c.currency_key = f.payment_currency_key
JOIN dw.dim_payment_format pf ON pf.payment_format_key = f.payment_format_key
GROUP BY d.date_key, d.full_date, c.currency_key, c.currency_name,
         pf.payment_format_key, pf.payment_format;

CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_daily_transaction
    ON mart.mv_daily_transaction (date_key, payment_currency_key, payment_format_key);

CREATE MATERIALIZED VIEW IF NOT EXISTS mart.mv_aml_by_payment_format AS
SELECT
    pf.payment_format_key,
    pf.payment_format,
    count(*) AS transaction_count,
    count(*) FILTER (WHERE f.is_laundering) AS laundering_count,
    round(100.0 * count(*) FILTER (WHERE f.is_laundering) / nullif(count(*), 0), 6)
        AS laundering_rate_percent
FROM dw.fact_transaction f
JOIN dw.dim_payment_format pf ON pf.payment_format_key = f.payment_format_key
GROUP BY pf.payment_format_key, pf.payment_format;

CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_aml_by_payment_format
    ON mart.mv_aml_by_payment_format (payment_format_key);

CREATE MATERIALIZED VIEW IF NOT EXISTS mart.mv_bank_activity AS
WITH bank_role AS
(
    SELECT from_bank_key AS bank_key, 'SENDER'::TEXT AS role_name, is_laundering
    FROM dw.fact_transaction
    UNION ALL
    SELECT to_bank_key, 'RECEIVER'::TEXT, is_laundering
    FROM dw.fact_transaction
)
SELECT
    b.bank_key,
    b.bank_id,
    b.bank_name,
    count(*) FILTER (WHERE r.role_name = 'SENDER') AS sent_count,
    count(*) FILTER (WHERE r.role_name = 'RECEIVER') AS received_count,
    count(*) AS total_participations,
    count(*) FILTER (WHERE r.is_laundering) AS laundering_participations
FROM bank_role r
JOIN dw.dim_bank b ON b.bank_key = r.bank_key
GROUP BY b.bank_key, b.bank_id, b.bank_name;

CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_bank_activity
    ON mart.mv_bank_activity (bank_key);

CREATE MATERIALIZED VIEW IF NOT EXISTS mart.mv_currency_flow AS
SELECT
    pc.currency_key AS payment_currency_key,
    pc.currency_name AS payment_currency,
    rc.currency_key AS receiving_currency_key,
    rc.currency_name AS receiving_currency,
    count(*) AS transaction_count,
    count(*) FILTER (WHERE f.is_laundering) AS laundering_count,
    sum(f.amount_paid) AS total_amount_paid,
    sum(f.amount_received) AS total_amount_received
FROM dw.fact_transaction f
JOIN dw.dim_currency pc ON pc.currency_key = f.payment_currency_key
JOIN dw.dim_currency rc ON rc.currency_key = f.receiving_currency_key
GROUP BY pc.currency_key, pc.currency_name, rc.currency_key, rc.currency_name;

CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_currency_flow
    ON mart.mv_currency_flow (payment_currency_key, receiving_currency_key);

CREATE MATERIALIZED VIEW IF NOT EXISTS mart.mv_pattern_summary AS
SELECT
    pt.pattern_type_key,
    pt.pattern_type,
    count(DISTINCT f.pattern_attempt_id) AS attempt_count,
    count(*) AS pattern_transaction_count,
    min(f.pattern_sequence) AS min_sequence,
    max(f.pattern_sequence) AS max_sequence
FROM dw.fact_pattern_transaction f
JOIN dw.dim_pattern_type pt ON pt.pattern_type_key = f.pattern_type_key
GROUP BY pt.pattern_type_key, pt.pattern_type;

CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_pattern_summary
    ON mart.mv_pattern_summary (pattern_type_key);

CREATE MATERIALIZED VIEW IF NOT EXISTS mart.mv_aml_account_risk AS
WITH aml_role AS
(
    SELECT from_account_key AS account_key, 'SENDER'::TEXT AS role_name,
           amount_paid AS role_amount
    FROM dw.fact_transaction
    WHERE is_laundering
    UNION ALL
    SELECT to_account_key, 'RECEIVER'::TEXT, amount_received
    FROM dw.fact_transaction
    WHERE is_laundering
)
SELECT
    a.account_key,
    a.bank_id,
    a.account_number,
    a.entity_id,
    count(*) FILTER (WHERE r.role_name = 'SENDER') AS laundering_sent_count,
    count(*) FILTER (WHERE r.role_name = 'RECEIVER') AS laundering_received_count,
    count(*) AS laundering_participations
FROM aml_role r
JOIN dw.dim_account a ON a.account_key = r.account_key
GROUP BY a.account_key, a.bank_id, a.account_number, a.entity_id;

CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_aml_account_risk
    ON mart.mv_aml_account_risk (account_key);

CREATE OR REPLACE PROCEDURE mart.refresh_all()
LANGUAGE plpgsql
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW mart.mv_kpi_overview;
    REFRESH MATERIALIZED VIEW mart.mv_daily_transaction;
    REFRESH MATERIALIZED VIEW mart.mv_aml_by_payment_format;
    REFRESH MATERIALIZED VIEW mart.mv_bank_activity;
    REFRESH MATERIALIZED VIEW mart.mv_currency_flow;
    REFRESH MATERIALIZED VIEW mart.mv_pattern_summary;
    REFRESH MATERIALIZED VIEW mart.mv_aml_account_risk;
    RAISE NOTICE 'All AML data marts refreshed';
END;
$$;

ANALYZE mart.mv_kpi_overview;
ANALYZE mart.mv_daily_transaction;
ANALYZE mart.mv_aml_by_payment_format;
ANALYZE mart.mv_bank_activity;
ANALYZE mart.mv_currency_flow;
ANALYZE mart.mv_pattern_summary;
ANALYZE mart.mv_aml_account_risk;

