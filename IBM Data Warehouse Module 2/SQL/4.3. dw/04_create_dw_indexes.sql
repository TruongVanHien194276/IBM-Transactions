/*
Chỉ chạy sau initial fact load để tránh làm chậm bulk insert
*/

-- transaction_key đã bằng source_transaction_id; constraint unique thứ hai
-- (nếu tồn tại từ bản DDL cũ) là index trùng và được loại bỏ
ALTER TABLE dw.fact_transaction
    DROP CONSTRAINT IF EXISTS ux_fact_transaction_source;

ALTER TABLE dw.fact_pattern_transaction
    DROP CONSTRAINT IF EXISTS fact_pattern_transaction_source_pattern_transaction_id_key;

CREATE INDEX IF NOT EXISTS ix_fact_transaction_date_brin
    ON dw.fact_transaction USING BRIN (date_key)
    WITH (pages_per_range = 128);

CREATE INDEX IF NOT EXISTS ix_fact_transaction_payment_currency_date
    ON dw.fact_transaction (payment_currency_key, date_key);

CREATE INDEX IF NOT EXISTS ix_fact_transaction_payment_format_date
    ON dw.fact_transaction (payment_format_key, date_key);

CREATE INDEX IF NOT EXISTS ix_fact_transaction_aml_partial
    ON dw.fact_transaction
        (date_key, payment_format_key, from_bank_key, to_bank_key)
    WHERE is_laundering;

CREATE INDEX IF NOT EXISTS ix_fact_pattern_type_attempt
    ON dw.fact_pattern_transaction
        (pattern_type_key, pattern_attempt_id, pattern_sequence);

CREATE INDEX IF NOT EXISTS ix_dw_batch_status
    ON etl.dw_batch (status, completed_at DESC);

CREATE INDEX IF NOT EXISTS ix_dw_rejected_batch
    ON etl.dw_rejected_row (dw_batch_id, error_code);

ANALYZE dw.dim_date;
ANALYZE dw.dim_time;
ANALYZE dw.dim_currency;
ANALYZE dw.dim_payment_format;
ANALYZE dw.dim_bank;
ANALYZE dw.dim_entity;
ANALYZE dw.dim_account;
ANALYZE dw.dim_pattern_type;
ANALYZE dw.fact_transaction;
ANALYZE dw.fact_pattern_transaction;
