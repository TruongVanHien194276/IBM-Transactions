/* Index ưu tiên truy vấn phân tích, tránh tạo nhiều B-tree trên bảng 31,9 triệu dòng. */

CREATE UNIQUE INDEX IF NOT EXISTS ux_account_business_key
    ON raw.account (bank_id, account_number);

CREATE INDEX IF NOT EXISTS ix_account_entity
    ON raw.account (entity_id)
    WHERE entity_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_transactions_timestamp_brin
    ON raw.transactions USING BRIN (transaction_timestamp)
    WITH (pages_per_range = 128);

CREATE INDEX IF NOT EXISTS ix_transactions_aml_partial
    ON raw.transactions (transaction_timestamp, payment_format)
    WHERE is_laundering;

CREATE INDEX IF NOT EXISTS ix_pattern_attempt
    ON raw.laundering_pattern_transaction (pattern_attempt_id, pattern_sequence);

CREATE OR REPLACE VIEW src.vw_bank AS
SELECT
    bank_id,
    max(bank_name) AS bank_name,
    count(*) AS account_count
FROM raw.account
GROUP BY bank_id;

CREATE OR REPLACE VIEW src.vw_transaction_business AS
SELECT
    source_transaction_id,
    source_row_id,
    transaction_timestamp,
    from_bank_id,
    from_account_id,
    to_bank_id,
    to_account_id,
    amount_paid,
    payment_currency,
    amount_received,
    receiving_currency,
    payment_format,
    is_laundering,
    from_bank_id <> to_bank_id AS is_cross_bank,
    payment_currency <> receiving_currency AS is_cross_currency,
    from_bank_id = to_bank_id
        AND from_account_id = to_account_id AS is_self_transfer,
    CASE
        WHEN payment_currency <> receiving_currency AND amount_paid > 0
        THEN amount_received / amount_paid
        ELSE NULL
    END AS implied_exchange_rate,
    load_batch_id,
    loaded_at
FROM raw.transactions;

ANALYZE raw.account;
ANALYZE raw.transactions;
ANALYZE raw.laundering_pattern_transaction;
