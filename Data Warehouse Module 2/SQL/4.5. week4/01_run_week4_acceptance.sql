/*
Tuần 4 - Chạy bộ kiểm thử nghiệm thu end-to-end

Phạm vi:
- ETL batch và validation
- Đối soát raw -> dw -> mart -> pbi
- Chất lượng dữ liệu và SCD Type 2
- KPI nghiệp vụ
- Reporting objects và quyền read-only

Script quét chính xác raw.transactions và dw.fact_transaction. Trên máy hiện
tại thời gian chạy dự kiến vài phút, tùy cache PostgreSQL.
*/

\set ON_ERROR_STOP on
\pset pager off
\timing on

DO $$
DECLARE
    v_run_id BIGINT;

    v_raw_count BIGINT;
    v_raw_laundering BIGINT;
    v_raw_cross_bank BIGINT;
    v_raw_cross_currency BIGINT;
    v_raw_self_transfer BIGINT;
    v_raw_min_date DATE;
    v_raw_max_date DATE;

    v_fact_count BIGINT;
    v_fact_laundering BIGINT;
    v_fact_cross_bank BIGINT;
    v_fact_cross_currency BIGINT;
    v_fact_self_transfer BIGINT;
    v_fact_invalid_amount BIGINT;
    v_fact_unknown_lookup BIGINT;

    v_source_pattern_count BIGINT;
    v_fact_pattern_count BIGINT;
    v_source_account_count BIGINT;
    v_current_account_count BIGINT;
    v_duplicate_current_account BIGINT;
    v_scd_overlap_count BIGINT;
    v_reject_count BIGINT;

    v_latest_batch_id BIGINT;
    v_latest_batch_status TEXT;
    v_latest_validation_status TEXT;
    v_latest_validation_failed BIGINT;
    v_no_change_incremental_count BIGINT;

    v_mart_count BIGINT;
    v_mart_populated_count BIGINT;
    v_pbi_view_count BIGINT;
    v_kpi RECORD;

    v_fact_pk_exists BOOLEAN;
    v_reader_role_exists BOOLEAN;
    v_reader_can_select BOOLEAN;
    v_reader_can_write_raw BOOLEAN;

    v_test_count INTEGER;
    v_passed_count INTEGER;
    v_failed_count INTEGER;
BEGIN
    INSERT INTO qa.week4_test_run
    (
        run_label,
        database_name,
        executed_by,
        postgres_version
    )
    VALUES
    (
        'IBM AML Week 4 Acceptance Test',
        current_database(),
        current_user,
        version()
    )
    RETURNING test_run_id INTO v_run_id;

    /*
    Hai phép aggregate dưới đây là phần nặng nhất nhưng chỉ quét mỗi bảng lớn
    đúng một lần.
    */
    SELECT
        count(*),
        count(*) FILTER (WHERE is_laundering),
        count(*) FILTER (WHERE from_bank_id <> to_bank_id),
        count(*) FILTER (WHERE payment_currency <> receiving_currency),
        count(*) FILTER
        (
            WHERE from_bank_id = to_bank_id
              AND from_account_id = to_account_id
        ),
        min(transaction_timestamp::DATE),
        max(transaction_timestamp::DATE)
    INTO
        v_raw_count,
        v_raw_laundering,
        v_raw_cross_bank,
        v_raw_cross_currency,
        v_raw_self_transfer,
        v_raw_min_date,
        v_raw_max_date
    FROM raw.transactions;

    SELECT
        count(*),
        count(*) FILTER (WHERE is_laundering),
        count(*) FILTER (WHERE is_cross_bank),
        count(*) FILTER (WHERE is_cross_currency),
        count(*) FILTER (WHERE is_self_transfer),
        count(*) FILTER (WHERE amount_paid <= 0 OR amount_received <= 0),
        count(*) FILTER
        (
            WHERE date_key = -1
               OR time_key = -1
               OR from_bank_key = -1
               OR to_bank_key = -1
               OR from_account_key = -1
               OR to_account_key = -1
               OR from_entity_key = -1
               OR to_entity_key = -1
               OR payment_currency_key = -1
               OR receiving_currency_key = -1
               OR payment_format_key = -1
        )
    INTO
        v_fact_count,
        v_fact_laundering,
        v_fact_cross_bank,
        v_fact_cross_currency,
        v_fact_self_transfer,
        v_fact_invalid_amount,
        v_fact_unknown_lookup
    FROM dw.fact_transaction;

    SELECT count(*)
    INTO v_source_pattern_count
    FROM raw.laundering_pattern_transaction;

    SELECT count(*)
    INTO v_fact_pattern_count
    FROM dw.fact_pattern_transaction;

    SELECT count(*)
    INTO v_source_account_count
    FROM raw.account;

    SELECT count(*)
    INTO v_current_account_count
    FROM dw.dim_account
    WHERE is_current
      AND account_key <> -1;

    SELECT count(*)
    INTO v_duplicate_current_account
    FROM
    (
        SELECT bank_id, account_number
        FROM dw.dim_account
        WHERE is_current
          AND account_key <> -1
        GROUP BY bank_id, account_number
        HAVING count(*) > 1
    ) d;

    SELECT count(*)
    INTO v_scd_overlap_count
    FROM
    (
        SELECT
            bank_id,
            account_number,
            effective_from,
            lag(effective_to) OVER
            (
                PARTITION BY bank_id, account_number
                ORDER BY effective_from
            ) AS previous_effective_to
        FROM dw.dim_account
        WHERE account_key <> -1
    ) s
    WHERE previous_effective_to > effective_from;

    SELECT count(*)
    INTO v_reject_count
    FROM etl.dw_rejected_row;

    SELECT
        dw_batch_id,
        status,
        validation_status
    INTO
        v_latest_batch_id,
        v_latest_batch_status,
        v_latest_validation_status
    FROM etl.dw_batch
    ORDER BY dw_batch_id DESC
    LIMIT 1;

    SELECT count(*)
    INTO v_latest_validation_failed
    FROM etl.dw_validation_result
    WHERE dw_batch_id = v_latest_batch_id
      AND status = 'FAILED';

    SELECT count(*)
    INTO v_no_change_incremental_count
    FROM etl.dw_batch
    WHERE load_type = 'INCREMENTAL'
      AND status = 'COMPLETED'
      AND validation_status = 'PASSED'
      AND transaction_rows_inserted = 0
      AND pattern_rows_inserted = 0;

    SELECT
        count(*),
        count(*) FILTER (WHERE ispopulated)
    INTO
        v_mart_count,
        v_mart_populated_count
    FROM pg_matviews
    WHERE schemaname = 'mart';

    SELECT count(*)
    INTO v_pbi_view_count
    FROM information_schema.views
    WHERE table_schema = 'pbi';

    SELECT *
    INTO v_kpi
    FROM pbi.kpi_overview;

    SELECT EXISTS
    (
        SELECT 1
        FROM pg_constraint c
        JOIN pg_class t ON t.oid = c.conrelid
        JOIN pg_namespace n ON n.oid = t.relnamespace
        WHERE n.nspname = 'dw'
          AND t.relname = 'fact_transaction'
          AND c.contype = 'p'
    )
    INTO v_fact_pk_exists;

    SELECT EXISTS
    (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'powerbi_readonly'
    )
    INTO v_reader_role_exists;

    IF v_reader_role_exists THEN
        SELECT has_table_privilege
        (
            'powerbi_readonly',
            'pbi.kpi_overview',
            'SELECT'
        )
        INTO v_reader_can_select;

        SELECT
            has_table_privilege
            (
                'powerbi_readonly',
                'raw.transactions',
                'INSERT'
            )
            OR has_table_privilege
            (
                'powerbi_readonly',
                'raw.transactions',
                'UPDATE'
            )
            OR has_table_privilege
            (
                'powerbi_readonly',
                'raw.transactions',
                'DELETE'
            )
        INTO v_reader_can_write_raw;
    ELSE
        v_reader_can_select := FALSE;
        v_reader_can_write_raw := TRUE;
    END IF;

    PERFORM qa.add_week4_test_result(
        v_run_id, 'ETL', 'ETL_01',
        'Batch gần nhất hoàn thành và validation PASSED',
        'COMPLETED / PASSED',
        coalesce(v_latest_batch_status, 'NULL') || ' / ' ||
            coalesce(v_latest_validation_status, 'NULL'),
        v_latest_batch_status = 'COMPLETED'
            AND v_latest_validation_status = 'PASSED',
        'dw_batch_id=' || coalesce(v_latest_batch_id::TEXT, 'NULL')
    );

    PERFORM qa.add_week4_test_result(
        v_run_id, 'ETL', 'ETL_02',
        'Validation gần nhất không có check FAILED',
        '0',
        v_latest_validation_failed::TEXT,
        v_latest_validation_failed = 0,
        'Đối chiếu etl.dw_validation_result'
    );

    PERFORM qa.add_week4_test_result(
        v_run_id, 'ETL', 'ETL_03',
        'Incremental no-change đã được chứng minh idempotent',
        '>= 1 batch',
        v_no_change_incremental_count::TEXT || ' batch',
        v_no_change_incremental_count >= 1,
        'Batch hoàn thành, PASSED và insert 0 transaction/pattern'
    );

    PERFORM qa.add_week4_test_result(
        v_run_id, 'RECONCILIATION', 'REC_01',
        'Số dòng raw.transactions khớp fact_transaction',
        v_raw_count::TEXT,
        v_fact_count::TEXT,
        v_raw_count = v_fact_count,
        'Grain: 1 source transaction = 1 fact row'
    );

    PERFORM qa.add_week4_test_result(
        v_run_id, 'RECONCILIATION', 'REC_02',
        'Số dòng pattern nguồn khớp pattern fact',
        v_source_pattern_count::TEXT,
        v_fact_pattern_count::TEXT,
        v_source_pattern_count = v_fact_pattern_count,
        'Grain: 1 pattern transaction = 1 pattern fact row'
    );

    PERFORM qa.add_week4_test_result(
        v_run_id, 'RECONCILIATION', 'REC_03',
        'Số tài khoản hiện hành khớp nguồn',
        v_source_account_count::TEXT,
        v_current_account_count::TEXT,
        v_source_account_count = v_current_account_count,
        'Không tính Unknown account_key=-1'
    );

    PERFORM qa.add_week4_test_result(
        v_run_id, 'DATA_QUALITY', 'DQ_01',
        'Không có amount không hợp lệ trong fact',
        '0',
        v_fact_invalid_amount::TEXT,
        v_fact_invalid_amount = 0,
        'amount_paid > 0 và amount_received > 0'
    );

    PERFORM qa.add_week4_test_result(
        v_run_id, 'DATA_QUALITY', 'DQ_02',
        'Không có Unknown dimension lookup trong fact',
        '0',
        v_fact_unknown_lookup::TEXT,
        v_fact_unknown_lookup = 0,
        'Kiểm tra toàn bộ role-playing dimension keys'
    );

    PERFORM qa.add_week4_test_result(
        v_run_id, 'DATA_QUALITY', 'DQ_03',
        'Không trùng business key ở account version hiện hành',
        '0',
        v_duplicate_current_account::TEXT,
        v_duplicate_current_account = 0,
        'Business key: bank_id + account_number'
    );

    PERFORM qa.add_week4_test_result(
        v_run_id, 'DATA_QUALITY', 'DQ_04',
        'Khoảng hiệu lực SCD Type 2 không chồng lấn',
        '0',
        v_scd_overlap_count::TEXT,
        v_scd_overlap_count = 0,
        'So sánh effective_from với effective_to của version trước'
    );

    PERFORM qa.add_week4_test_result(
        v_run_id, 'DATA_QUALITY', 'DQ_05',
        'Không có bản ghi bị reject trong dataset hiện tại',
        '0',
        v_reject_count::TEXT,
        v_reject_count = 0,
        'Reject framework vẫn được giữ để xử lý dữ liệu tương lai'
    );

    PERFORM qa.add_week4_test_result(
        v_run_id, 'DATA_WAREHOUSE', 'DW_01',
        'fact_transaction có primary key chống trùng',
        'TRUE',
        v_fact_pk_exists::TEXT,
        v_fact_pk_exists,
        'transaction_key là primary key'
    );

    PERFORM qa.add_week4_test_result(
        v_run_id, 'DATA_WAREHOUSE', 'DW_02',
        'Bảy materialized data mart đều populated',
        '7 / 7',
        v_mart_populated_count::TEXT || ' / ' || v_mart_count::TEXT,
        v_mart_count = 7 AND v_mart_populated_count = 7,
        'Schema mart'
    );

    PERFORM qa.add_week4_test_result(
        v_run_id, 'BUSINESS_RULE', 'BR_01',
        'Laundering count giữ nguyên nhãn nguồn',
        v_raw_laundering::TEXT,
        v_fact_laundering::TEXT,
        v_raw_laundering = v_fact_laundering
            AND v_fact_laundering = 35230,
        'Nhãn synthetic ground truth, không phải cảnh báo dự đoán'
    );

    PERFORM qa.add_week4_test_result(
        v_run_id, 'BUSINESS_RULE', 'BR_02',
        'Cross-bank count đúng định nghĩa nghiệp vụ',
        v_raw_cross_bank::TEXT,
        v_fact_cross_bank::TEXT,
        v_raw_cross_bank = v_fact_cross_bank
            AND v_fact_cross_bank = 29092624,
        'from_bank_id khác to_bank_id'
    );

    PERFORM qa.add_week4_test_result(
        v_run_id, 'BUSINESS_RULE', 'BR_03',
        'Cross-currency count đúng định nghĩa nghiệp vụ',
        v_raw_cross_currency::TEXT,
        v_fact_cross_currency::TEXT,
        v_raw_cross_currency = v_fact_cross_currency
            AND v_fact_cross_currency = 485144,
        'payment_currency khác receiving_currency'
    );

    PERFORM qa.add_week4_test_result(
        v_run_id, 'BUSINESS_RULE', 'BR_04',
        'Self-transfer count đúng định nghĩa nghiệp vụ',
        v_raw_self_transfer::TEXT,
        v_fact_self_transfer::TEXT,
        v_raw_self_transfer = v_fact_self_transfer
            AND v_fact_self_transfer = 2561860,
        'Cùng bank và cùng account'
    );

    PERFORM qa.add_week4_test_result(
        v_run_id, 'BUSINESS_RULE', 'BR_05',
        'Khoảng ngày giao dịch đúng dataset',
        '2022-09-01 -> 2022-09-28',
        v_raw_min_date::TEXT || ' -> ' || v_raw_max_date::TEXT,
        v_raw_min_date = DATE '2022-09-01'
            AND v_raw_max_date = DATE '2022-09-28',
        'Ngày được lấy trực tiếp từ raw.transactions'
    );

    PERFORM qa.add_week4_test_result(
        v_run_id, 'POWER_BI', 'PBI_01',
        'Đủ 16 reporting views',
        '16',
        v_pbi_view_count::TEXT,
        v_pbi_view_count = 16,
        'Schema pbi'
    );

    PERFORM qa.add_week4_test_result(
        v_run_id, 'POWER_BI', 'PBI_02',
        'KPI reporting layer khớp fact',
        v_fact_count::TEXT || ' transactions; ' ||
            v_fact_laundering::TEXT || ' laundering',
        v_kpi.transaction_count::TEXT || ' transactions; ' ||
            v_kpi.laundering_count::TEXT || ' laundering',
        v_kpi.transaction_count = v_fact_count
            AND v_kpi.laundering_count = v_fact_laundering
            AND v_kpi.cross_bank_count = v_fact_cross_bank
            AND v_kpi.cross_currency_count = v_fact_cross_currency
            AND v_kpi.self_transfer_count = v_fact_self_transfer,
        'pbi.kpi_overview -> mart.mv_kpi_overview -> dw.fact_transaction'
    );

    PERFORM qa.add_week4_test_result(
        v_run_id, 'SECURITY', 'SEC_01',
        'Role báo cáo chỉ đọc tồn tại và được SELECT pbi',
        'TRUE',
        (v_reader_role_exists AND v_reader_can_select)::TEXT,
        v_reader_role_exists AND v_reader_can_select,
        'Role powerbi_readonly'
    );

    PERFORM qa.add_week4_test_result(
        v_run_id, 'SECURITY', 'SEC_02',
        'Role báo cáo không được ghi raw.transactions',
        'FALSE',
        v_reader_can_write_raw::TEXT,
        NOT v_reader_can_write_raw,
        'Kiểm tra INSERT/UPDATE/DELETE'
    );

    SELECT
        count(*),
        count(*) FILTER (WHERE status = 'PASSED'),
        count(*) FILTER (WHERE status = 'FAILED')
    INTO
        v_test_count,
        v_passed_count,
        v_failed_count
    FROM qa.week4_test_result
    WHERE test_run_id = v_run_id;

    UPDATE qa.week4_test_run
    SET
        completed_at = clock_timestamp(),
        test_count = v_test_count,
        passed_count = v_passed_count,
        failed_count = v_failed_count,
        status = CASE WHEN v_failed_count = 0 THEN 'PASSED' ELSE 'FAILED' END
    WHERE test_run_id = v_run_id;
EXCEPTION
    WHEN OTHERS THEN
        IF v_run_id IS NOT NULL THEN
            UPDATE qa.week4_test_run
            SET
                completed_at = clock_timestamp(),
                status = 'FAILED'
            WHERE test_run_id = v_run_id;
        END IF;
        RAISE;
END
$$;

\timing off

SELECT
    test_run_id,
    run_label,
    database_name,
    executed_by,
    started_at,
    completed_at,
    round
    (
        extract(epoch FROM (completed_at - started_at))::NUMERIC,
        2
    ) AS duration_seconds,
    test_count,
    passed_count,
    failed_count,
    status
FROM qa.v_week4_latest_run;

SELECT
    category,
    test_code,
    test_name,
    expected_value,
    actual_value,
    status,
    details
FROM qa.v_week4_latest_results;
