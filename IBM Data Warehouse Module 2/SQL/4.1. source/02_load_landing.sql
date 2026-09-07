/*
Chạy trực tiếp trong DBeaver, connection aml_source
*/

BEGIN;

UPDATE etl.load_batch
SET completed_at = clock_timestamp(),
    status = 'FAILED',
    error_message = 'Batch cũ bị thay thế trước lần full load mới'
WHERE status = 'STARTED';

TRUNCATE TABLE
    raw.transaction_landing,
    raw.account_landing,
    raw.pattern_transaction_landing
RESTART IDENTITY;

TRUNCATE TABLE
    raw.transactions,
    raw.laundering_pattern_transaction,
    raw.account,
    raw.rejected_row
RESTART IDENTITY;

INSERT INTO etl.load_batch (dataset_name, source_version, status)
VALUES ('IBM Transactions for Anti Money Laundering - HI-Medium', 'Kaggle v8', 'STARTED');

COPY raw.account_landing
(
    bank_name_text,
    bank_id_text,
    account_number_text,
    entity_id_text,
    entity_name_text
)
FROM '/Users/hoangyugi001/Documents/Coder/IBM Transactions/data/raw/HI-Medium_accounts.csv'
WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

COPY raw.transaction_landing
(
    timestamp_text,
    from_bank_text,
    from_account_text,
    to_bank_text,
    to_account_text,
    amount_received_text,
    receiving_currency_text,
    amount_paid_text,
    payment_currency_text,
    payment_format_text,
    is_laundering_text
)
FROM '/Users/hoangyugi001/Documents/Coder/IBM Transactions/data/raw/HI-Medium_Trans.csv'
WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

COPY raw.pattern_transaction_landing
(
    pattern_attempt_id_text,
    pattern_type_text,
    pattern_description_text,
    pattern_sequence_text,
    timestamp_text,
    from_bank_text,
    from_account_text,
    to_bank_text,
    to_account_text,
    amount_received_text,
    receiving_currency_text,
    amount_paid_text,
    payment_currency_text,
    payment_format_text,
    is_laundering_text
)
FROM '/Users/hoangyugi001/Documents/Coder/IBM Transactions/data/processed/HI-Medium_PatternTransactions.csv'
WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

UPDATE etl.load_batch
SET account_landing_rows = (SELECT count(*) FROM raw.account_landing),
    transaction_landing_rows = (SELECT count(*) FROM raw.transaction_landing),
    pattern_landing_rows = (SELECT count(*) FROM raw.pattern_transaction_landing)
WHERE batch_id =
(
    SELECT max(batch_id)
    FROM etl.load_batch
    WHERE status = 'STARTED'
);

COMMIT;

SELECT *
FROM etl.load_batch
ORDER BY batch_id DESC
LIMIT 1;
