/*
Chuẩn hóa landing text sang source typed
Quy tắc: Bank ID được chuyển qua BIGINT rồi về TEXT để bỏ số 0 đầu
khóa tài khoản nghiệp vụ là (bank_id, account_number)
*/

BEGIN;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM etl.load_batch WHERE status = 'STARTED') THEN
        RAISE EXCEPTION 'Không có batch STARTED. Hãy chạy 02_load_landing.sql trước.';
    END IF;
END
$$;

CREATE TEMP TABLE current_load_batch ON COMMIT DROP AS
SELECT max(batch_id) AS batch_id
FROM etl.load_batch
WHERE status = 'STARTED';

INSERT INTO raw.rejected_row
(
    batch_id, source_object, source_row_id,
    error_code, error_description, raw_payload
)
SELECT
    b.batch_id,
    'Account',
    a.landing_row_id,
    'INVALID_ACCOUNT',
    'Bank ID hoặc account number không hợp lệ',
    concat_ws('|', a.bank_name_text, a.bank_id_text, a.account_number_text,
              a.entity_id_text, a.entity_name_text)
FROM raw.account_landing a
CROSS JOIN current_load_batch b
WHERE btrim(coalesce(a.bank_id_text, '')) !~ '^[0-9]+$'
   OR nullif(btrim(a.account_number_text), '') IS NULL;

INSERT INTO raw.account
(
    source_row_id, bank_name, raw_bank_id, bank_id,
    account_number, entity_id, entity_name, load_batch_id
)
SELECT
    a.landing_row_id,
    btrim(a.bank_name_text),
    btrim(a.bank_id_text),
    (btrim(a.bank_id_text)::BIGINT)::TEXT,
    upper(btrim(a.account_number_text)),
    upper(nullif(btrim(a.entity_id_text), '')),
    nullif(btrim(a.entity_name_text), ''),
    b.batch_id
FROM raw.account_landing a
CROSS JOIN current_load_batch b
WHERE btrim(coalesce(a.bank_id_text, '')) ~ '^[0-9]+$'
  AND nullif(btrim(a.account_number_text), '') IS NOT NULL;

INSERT INTO raw.rejected_row
(
    batch_id, source_object, source_row_id,
    error_code, error_description, raw_payload
)
SELECT
    b.batch_id,
    'Transaction',
    t.landing_row_id,
    'INVALID_TRANSACTION',
    'Timestamp, account, bank, amount, currency, payment format hoặc AML label không hợp lệ',
    concat_ws('|', t.timestamp_text, t.from_bank_text, t.from_account_text,
              t.to_bank_text, t.to_account_text, t.amount_received_text,
              t.receiving_currency_text, t.amount_paid_text,
              t.payment_currency_text, t.payment_format_text, t.is_laundering_text)
FROM raw.transaction_landing t
CROSS JOIN current_load_batch b
WHERE btrim(coalesce(t.timestamp_text, '')) !~ '^[0-9]{4}/[0-9]{2}/[0-9]{2} [0-9]{2}:[0-9]{2}$'
   OR btrim(coalesce(t.from_bank_text, '')) !~ '^[0-9]+$'
   OR btrim(coalesce(t.to_bank_text, '')) !~ '^[0-9]+$'
   OR nullif(btrim(t.from_account_text), '') IS NULL
   OR nullif(btrim(t.to_account_text), '') IS NULL
   OR btrim(coalesce(t.amount_received_text, '')) !~ '^[+-]?[0-9]+([.][0-9]+)?$'
   OR btrim(coalesce(t.amount_paid_text, '')) !~ '^[+-]?[0-9]+([.][0-9]+)?$'
   OR nullif(btrim(t.receiving_currency_text), '') IS NULL
   OR nullif(btrim(t.payment_currency_text), '') IS NULL
   OR nullif(btrim(t.payment_format_text), '') IS NULL
   OR btrim(coalesce(t.is_laundering_text, '')) !~ '^(0|1)$';

INSERT INTO raw.transactions
(
    source_row_id, transaction_timestamp,
    raw_from_bank_id, from_bank_id, from_account_id,
    raw_to_bank_id, to_bank_id, to_account_id,
    amount_received, receiving_currency,
    amount_paid, payment_currency, payment_format,
    is_laundering, load_batch_id
)
SELECT
    t.landing_row_id,
    to_timestamp(btrim(t.timestamp_text), 'YYYY/MM/DD HH24:MI')::TIMESTAMP,
    btrim(t.from_bank_text),
    (btrim(t.from_bank_text)::BIGINT)::TEXT,
    upper(btrim(t.from_account_text)),
    btrim(t.to_bank_text),
    (btrim(t.to_bank_text)::BIGINT)::TEXT,
    upper(btrim(t.to_account_text)),
    btrim(t.amount_received_text)::NUMERIC(24,8),
    btrim(t.receiving_currency_text),
    btrim(t.amount_paid_text)::NUMERIC(24,8),
    btrim(t.payment_currency_text),
    btrim(t.payment_format_text),
    btrim(t.is_laundering_text) = '1',
    b.batch_id
FROM raw.transaction_landing t
CROSS JOIN current_load_batch b
WHERE btrim(coalesce(t.timestamp_text, '')) ~ '^[0-9]{4}/[0-9]{2}/[0-9]{2} [0-9]{2}:[0-9]{2}$'
  AND btrim(coalesce(t.from_bank_text, '')) ~ '^[0-9]+$'
  AND btrim(coalesce(t.to_bank_text, '')) ~ '^[0-9]+$'
  AND nullif(btrim(t.from_account_text), '') IS NOT NULL
  AND nullif(btrim(t.to_account_text), '') IS NOT NULL
  AND btrim(coalesce(t.amount_received_text, '')) ~ '^[+-]?[0-9]+([.][0-9]+)?$'
  AND btrim(coalesce(t.amount_paid_text, '')) ~ '^[+-]?[0-9]+([.][0-9]+)?$'
  AND nullif(btrim(t.receiving_currency_text), '') IS NOT NULL
  AND nullif(btrim(t.payment_currency_text), '') IS NOT NULL
  AND nullif(btrim(t.payment_format_text), '') IS NOT NULL
  AND btrim(coalesce(t.is_laundering_text, '')) ~ '^(0|1)$';

INSERT INTO raw.rejected_row
(
    batch_id, source_object, source_row_id,
    error_code, error_description, raw_payload
)
SELECT
    b.batch_id,
    'PatternTransaction',
    p.landing_row_id,
    'INVALID_PATTERN_TRANSACTION',
    'Pattern attempt, sequence hoặc trường giao dịch không hợp lệ',
    concat_ws('|', p.pattern_attempt_id_text, p.pattern_type_text,
              p.pattern_description_text, p.pattern_sequence_text,
              p.timestamp_text, p.from_bank_text, p.from_account_text,
              p.to_bank_text, p.to_account_text, p.amount_received_text,
              p.receiving_currency_text, p.amount_paid_text,
              p.payment_currency_text, p.payment_format_text, p.is_laundering_text)
FROM raw.pattern_transaction_landing p
CROSS JOIN current_load_batch b
WHERE btrim(coalesce(p.pattern_attempt_id_text, '')) !~ '^[0-9]+$'
   OR btrim(coalesce(p.pattern_sequence_text, '')) !~ '^[0-9]+$'
   OR btrim(coalesce(p.timestamp_text, '')) !~ '^[0-9]{4}/[0-9]{2}/[0-9]{2} [0-9]{2}:[0-9]{2}$'
   OR btrim(coalesce(p.from_bank_text, '')) !~ '^[0-9]+$'
   OR btrim(coalesce(p.to_bank_text, '')) !~ '^[0-9]+$'
   OR btrim(coalesce(p.amount_received_text, '')) !~ '^[+-]?[0-9]+([.][0-9]+)?$'
   OR btrim(coalesce(p.amount_paid_text, '')) !~ '^[+-]?[0-9]+([.][0-9]+)?$'
   OR btrim(coalesce(p.is_laundering_text, '')) !~ '^(0|1)$'
   OR nullif(btrim(p.pattern_type_text), '') IS NULL
   OR nullif(btrim(p.pattern_description_text), '') IS NULL
   OR nullif(btrim(p.from_account_text), '') IS NULL
   OR nullif(btrim(p.to_account_text), '') IS NULL
   OR nullif(btrim(p.receiving_currency_text), '') IS NULL
   OR nullif(btrim(p.payment_currency_text), '') IS NULL
   OR nullif(btrim(p.payment_format_text), '') IS NULL;

INSERT INTO raw.laundering_pattern_transaction
(
    pattern_attempt_id, pattern_type, pattern_description, pattern_sequence,
    transaction_timestamp, from_bank_id, from_account_id,
    to_bank_id, to_account_id, amount_received, receiving_currency,
    amount_paid, payment_currency, payment_format,
    is_laundering, load_batch_id
)
SELECT
    btrim(p.pattern_attempt_id_text)::BIGINT,
    btrim(p.pattern_type_text),
    btrim(p.pattern_description_text),
    btrim(p.pattern_sequence_text)::INTEGER,
    to_timestamp(btrim(p.timestamp_text), 'YYYY/MM/DD HH24:MI')::TIMESTAMP,
    (btrim(p.from_bank_text)::BIGINT)::TEXT,
    upper(btrim(p.from_account_text)),
    (btrim(p.to_bank_text)::BIGINT)::TEXT,
    upper(btrim(p.to_account_text)),
    btrim(p.amount_received_text)::NUMERIC(24,8),
    btrim(p.receiving_currency_text),
    btrim(p.amount_paid_text)::NUMERIC(24,8),
    btrim(p.payment_currency_text),
    btrim(p.payment_format_text),
    btrim(p.is_laundering_text) = '1',
    b.batch_id
FROM raw.pattern_transaction_landing p
CROSS JOIN current_load_batch b
WHERE btrim(coalesce(p.pattern_attempt_id_text, '')) ~ '^[0-9]+$'
  AND btrim(coalesce(p.pattern_sequence_text, '')) ~ '^[0-9]+$'
  AND btrim(coalesce(p.timestamp_text, '')) ~ '^[0-9]{4}/[0-9]{2}/[0-9]{2} [0-9]{2}:[0-9]{2}$'
  AND btrim(coalesce(p.from_bank_text, '')) ~ '^[0-9]+$'
  AND btrim(coalesce(p.to_bank_text, '')) ~ '^[0-9]+$'
  AND btrim(coalesce(p.amount_received_text, '')) ~ '^[+-]?[0-9]+([.][0-9]+)?$'
  AND btrim(coalesce(p.amount_paid_text, '')) ~ '^[+-]?[0-9]+([.][0-9]+)?$'
  AND btrim(coalesce(p.is_laundering_text, '')) ~ '^(0|1)$'
  AND nullif(btrim(p.pattern_type_text), '') IS NOT NULL
  AND nullif(btrim(p.pattern_description_text), '') IS NOT NULL
  AND nullif(btrim(p.from_account_text), '') IS NOT NULL
  AND nullif(btrim(p.to_account_text), '') IS NOT NULL
  AND nullif(btrim(p.receiving_currency_text), '') IS NOT NULL
  AND nullif(btrim(p.payment_currency_text), '') IS NOT NULL
  AND nullif(btrim(p.payment_format_text), '') IS NOT NULL;

UPDATE etl.load_batch lb
SET completed_at = clock_timestamp(),
    status = 'COMPLETED',
    account_loaded_rows = (SELECT count(*) FROM raw.account),
    transaction_loaded_rows = (SELECT count(*) FROM raw.transactions),
    pattern_loaded_rows = (SELECT count(*) FROM raw.laundering_pattern_transaction),
    rejected_rows = (SELECT count(*) FROM raw.rejected_row r WHERE r.batch_id = lb.batch_id)
WHERE lb.batch_id = (SELECT batch_id FROM current_load_batch);

COMMIT;

SELECT *
FROM etl.load_batch
ORDER BY batch_id DESC
LIMIT 1;
