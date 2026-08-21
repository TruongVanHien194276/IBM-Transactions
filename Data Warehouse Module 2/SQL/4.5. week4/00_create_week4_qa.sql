/*
Tuần 4 - Khởi tạo lớp kiểm thử nghiệm thu
Database: aml_source

Lớp qa chỉ lưu bằng chứng kiểm thử. Script không thay đổi dữ liệu raw, stg, dw,
mart hoặc pbi.
*/

\set ON_ERROR_STOP on
\pset pager off

DO $$
BEGIN
    IF current_database() <> 'aml_source' THEN
        RAISE EXCEPTION
            'Sai database: hãy đổi connection sang aml_source trước khi chạy';
    END IF;
END
$$;

BEGIN;

CREATE SCHEMA IF NOT EXISTS qa;

CREATE TABLE IF NOT EXISTS qa.week4_test_run
(
    test_run_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    run_label         TEXT NOT NULL,
    database_name     TEXT NOT NULL,
    executed_by       TEXT NOT NULL,
    postgres_version  TEXT NOT NULL,
    started_at        TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    completed_at      TIMESTAMPTZ,
    test_count        INTEGER NOT NULL DEFAULT 0,
    passed_count      INTEGER NOT NULL DEFAULT 0,
    failed_count      INTEGER NOT NULL DEFAULT 0,
    status            VARCHAR(12) NOT NULL DEFAULT 'RUNNING',
    CONSTRAINT ck_week4_test_run_status
        CHECK (status IN ('RUNNING', 'PASSED', 'FAILED'))
);

CREATE TABLE IF NOT EXISTS qa.week4_test_result
(
    test_result_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    test_run_id     BIGINT NOT NULL
        REFERENCES qa.week4_test_run(test_run_id),
    category        TEXT NOT NULL,
    test_code       TEXT NOT NULL,
    test_name       TEXT NOT NULL,
    expected_value  TEXT NOT NULL,
    actual_value    TEXT NOT NULL,
    status          VARCHAR(10) NOT NULL,
    details         TEXT,
    checked_at      TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT ux_week4_test_result UNIQUE (test_run_id, test_code),
    CONSTRAINT ck_week4_test_result_status
        CHECK (status IN ('PASSED', 'FAILED'))
);

CREATE INDEX IF NOT EXISTS ix_week4_test_result_run
    ON qa.week4_test_result (test_run_id, status, category);

CREATE OR REPLACE FUNCTION qa.add_week4_test_result
(
    p_test_run_id BIGINT,
    p_category TEXT,
    p_test_code TEXT,
    p_test_name TEXT,
    p_expected_value TEXT,
    p_actual_value TEXT,
    p_is_passed BOOLEAN,
    p_details TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE sql
AS $$
    INSERT INTO qa.week4_test_result
    (
        test_run_id,
        category,
        test_code,
        test_name,
        expected_value,
        actual_value,
        status,
        details
    )
    VALUES
    (
        p_test_run_id,
        p_category,
        p_test_code,
        p_test_name,
        p_expected_value,
        p_actual_value,
        CASE WHEN p_is_passed THEN 'PASSED' ELSE 'FAILED' END,
        p_details
    );
$$;

CREATE OR REPLACE VIEW qa.v_week4_latest_run AS
SELECT r.*
FROM qa.week4_test_run r
WHERE r.test_run_id =
(
    SELECT max(test_run_id)
    FROM qa.week4_test_run
);

CREATE OR REPLACE VIEW qa.v_week4_latest_results AS
SELECT
    r.test_run_id,
    r.run_label,
    r.status AS run_status,
    t.category,
    t.test_code,
    t.test_name,
    t.expected_value,
    t.actual_value,
    t.status,
    t.details,
    t.checked_at
FROM qa.v_week4_latest_run r
JOIN qa.week4_test_result t
  ON t.test_run_id = r.test_run_id
ORDER BY
    CASE t.category
        WHEN 'ETL' THEN 1
        WHEN 'RECONCILIATION' THEN 2
        WHEN 'DATA_QUALITY' THEN 3
        WHEN 'BUSINESS_RULE' THEN 4
        WHEN 'DATA_WAREHOUSE' THEN 5
        WHEN 'POWER_BI' THEN 6
        WHEN 'SECURITY' THEN 7
        ELSE 8
    END,
    t.test_code;

COMMENT ON SCHEMA qa IS
    'Audit evidence for Week 4 acceptance testing; no business data is stored.';
COMMENT ON TABLE qa.week4_test_run IS
    'One row per Week 4 acceptance-test execution.';
COMMENT ON TABLE qa.week4_test_result IS
    'Detailed PASS/FAIL evidence for each Week 4 acceptance test.';

COMMIT;

SELECT
    'qa.week4_test_run' AS object_name,
    'READY' AS status
UNION ALL
SELECT
    'qa.week4_test_result',
    'READY';
