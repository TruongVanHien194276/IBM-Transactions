/*
Chạy trong connection trỏ tới database aml_source
Landing tables là UNLOGGED vì chỉ là vùng nhận tạm có thể nạp lại từ CSV
*/

DO $$
BEGIN
    IF current_database() <> 'aml_source' THEN
        RAISE EXCEPTION 'Sai database: kết nối aml_source trước khi chạy script';
    END IF;
END
$$;

BEGIN;

CREATE SCHEMA IF NOT EXISTS etl;
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS src;

CREATE TABLE IF NOT EXISTS etl.load_batch
(
    batch_id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dataset_name              TEXT NOT NULL,
    source_version            VARCHAR(30),
    started_at                TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    completed_at              TIMESTAMPTZ,
    status                    VARCHAR(20) NOT NULL,
    account_landing_rows      BIGINT,
    transaction_landing_rows  BIGINT,
    pattern_landing_rows      BIGINT,
    account_loaded_rows       BIGINT,
    transaction_loaded_rows   BIGINT,
    pattern_loaded_rows       BIGINT,
    rejected_rows             BIGINT,
    error_message             TEXT,
    CONSTRAINT ck_load_batch_status
        CHECK (status IN ('STARTED', 'COMPLETED', 'FAILED'))
);

CREATE UNLOGGED TABLE IF NOT EXISTS raw.account_landing
(
    landing_row_id      BIGINT GENERATED ALWAYS AS IDENTITY,
    bank_name_text      TEXT,
    bank_id_text        TEXT,
    account_number_text TEXT,
    entity_id_text      TEXT,
    entity_name_text    TEXT
);

CREATE UNLOGGED TABLE IF NOT EXISTS raw.transaction_landing
(
    landing_row_id           BIGINT GENERATED ALWAYS AS IDENTITY,
    timestamp_text           TEXT,
    from_bank_text           TEXT,
    from_account_text        TEXT,
    to_bank_text             TEXT,
    to_account_text          TEXT,
    amount_received_text     TEXT,
    receiving_currency_text  TEXT,
    amount_paid_text         TEXT,
    payment_currency_text    TEXT,
    payment_format_text      TEXT,
    is_laundering_text       TEXT
);

CREATE UNLOGGED TABLE IF NOT EXISTS raw.pattern_transaction_landing
(
    landing_row_id            BIGINT GENERATED ALWAYS AS IDENTITY,
    pattern_attempt_id_text   TEXT,
    pattern_type_text         TEXT,
    pattern_description_text  TEXT,
    pattern_sequence_text     TEXT,
    timestamp_text            TEXT,
    from_bank_text            TEXT,
    from_account_text         TEXT,
    to_bank_text              TEXT,
    to_account_text           TEXT,
    amount_received_text      TEXT,
    receiving_currency_text   TEXT,
    amount_paid_text          TEXT,
    payment_currency_text     TEXT,
    payment_format_text       TEXT,
    is_laundering_text        TEXT
);

CREATE TABLE IF NOT EXISTS raw.rejected_row
(
    rejected_row_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    batch_id          BIGINT NOT NULL,
    source_object     VARCHAR(50) NOT NULL,
    source_row_id     BIGINT,
    error_code        VARCHAR(50) NOT NULL,
    error_description TEXT NOT NULL,
    raw_payload       TEXT,
    rejected_at       TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE IF NOT EXISTS raw.account
(
    source_account_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_row_id     BIGINT NOT NULL,
    bank_name         TEXT NOT NULL,
    raw_bank_id       TEXT NOT NULL,
    bank_id           TEXT NOT NULL,
    account_number    TEXT NOT NULL,
    entity_id         TEXT,
    entity_name       TEXT,
    load_batch_id     BIGINT NOT NULL,
    loaded_at         TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE IF NOT EXISTS raw.transactions
(
    source_transaction_id BIGINT GENERATED ALWAYS AS IDENTITY,
    source_row_id          BIGINT NOT NULL,
    transaction_timestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    raw_from_bank_id       TEXT NOT NULL,
    from_bank_id           TEXT NOT NULL,
    from_account_id        TEXT NOT NULL,
    raw_to_bank_id         TEXT NOT NULL,
    to_bank_id             TEXT NOT NULL,
    to_account_id          TEXT NOT NULL,
    amount_received        NUMERIC(24,8) NOT NULL,
    receiving_currency     TEXT NOT NULL,
    amount_paid            NUMERIC(24,8) NOT NULL,
    payment_currency       TEXT NOT NULL,
    payment_format         TEXT NOT NULL,
    is_laundering          BOOLEAN NOT NULL,
    load_batch_id          BIGINT NOT NULL,
    loaded_at              TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE IF NOT EXISTS raw.laundering_pattern_transaction
(
    pattern_transaction_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pattern_attempt_id     BIGINT NOT NULL,
    pattern_type           TEXT NOT NULL,
    pattern_description    TEXT NOT NULL,
    pattern_sequence       INTEGER NOT NULL,
    transaction_timestamp  TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    from_bank_id            TEXT NOT NULL,
    from_account_id         TEXT NOT NULL,
    to_bank_id              TEXT NOT NULL,
    to_account_id           TEXT NOT NULL,
    amount_received         NUMERIC(24,8) NOT NULL,
    receiving_currency      TEXT NOT NULL,
    amount_paid             NUMERIC(24,8) NOT NULL,
    payment_currency        TEXT NOT NULL,
    payment_format          TEXT NOT NULL,
    is_laundering           BOOLEAN NOT NULL,
    load_batch_id           BIGINT NOT NULL,
    loaded_at               TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

COMMIT;
