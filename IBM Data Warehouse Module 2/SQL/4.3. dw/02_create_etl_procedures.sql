/*
Tạo ETL FULL/INCREMENTAL và validation procedure

ETL có tính idempotent:
- Dimension Type 1 dùng UPSERT
- dim_account dùng SCD Type 2
- Fact dùng source technical key + ON CONFLICT DO NOTHING
- Incremental dùng watermark source_transaction_id/pattern_transaction_id
*/

CREATE OR REPLACE PROCEDURE etl.load_dw(p_load_type TEXT DEFAULT 'INCREMENTAL')
LANGUAGE plpgsql
AS $$
DECLARE
    v_load_type             TEXT := upper(btrim(p_load_type));
    v_batch_id              BIGINT;
    v_started_at            TIMESTAMPTZ;
    v_previous_watermark    BIGINT := 0;
    v_high_watermark        BIGINT := 0;
    v_previous_pattern_wm   BIGINT := 0;
    v_high_pattern_wm       BIGINT := 0;
    v_rows                   BIGINT := 0;
    v_bank_rows              BIGINT := 0;
    v_entity_rows            BIGINT := 0;
    v_account_rows           BIGINT := 0;
    v_currency_rows          BIGINT := 0;
    v_format_rows            BIGINT := 0;
    v_fact_rows              BIGINT := 0;
    v_pattern_rows           BIGINT := 0;
    v_rejected_rows          BIGINT := 0;
    v_error                  TEXT;
BEGIN
    IF current_database() <> 'aml_source' THEN
        RAISE EXCEPTION 'Sai database: hãy đổi connection sang aml_source trước khi CALL';
    END IF;

    IF v_load_type NOT IN ('FULL', 'INCREMENTAL') THEN
        RAISE EXCEPTION 'load_type chỉ nhận FULL hoặc INCREMENTAL, nhận được: %', p_load_type;
    END IF;

    IF NOT pg_try_advisory_xact_lock(hashtext('IBM_AML_ETL_LOAD_DW')) THEN
        RAISE EXCEPTION 'Một tiến trình ETL Data Warehouse khác đang chạy';
    END IF;

    PERFORM set_config('synchronous_commit', 'off', TRUE);
    PERFORM set_config('work_mem', '128MB', TRUE);

    IF v_load_type = 'INCREMENTAL' THEN
        SELECT
            coalesce(max(source_high_watermark), 0),
            coalesce(max(pattern_high_watermark), 0)
        INTO v_previous_watermark, v_previous_pattern_wm
        FROM etl.dw_batch
        WHERE status = 'COMPLETED';
    END IF;

    SELECT coalesce(max(source_transaction_id), 0)
    INTO v_high_watermark
    FROM raw.transactions;

    SELECT coalesce(max(pattern_transaction_id), 0)
    INTO v_high_pattern_wm
    FROM raw.laundering_pattern_transaction;

    INSERT INTO etl.dw_batch
        (load_type, status,
         source_low_watermark, source_high_watermark,
         pattern_low_watermark, pattern_high_watermark)
    VALUES
        (v_load_type, 'STARTED',
         v_previous_watermark + 1, v_high_watermark,
         v_previous_pattern_wm + 1, v_high_pattern_wm)
    RETURNING dw_batch_id, started_at INTO v_batch_id, v_started_at;

    BEGIN
        -- Date dimension: chỉ bổ sung những ngày xuất hiện trong delta.
        INSERT INTO dw.dim_date
            (date_key, full_date, day_of_month, day_of_week, day_name,
             week_of_year, month_number, month_name, quarter_number,
             year_number, is_weekend)
        SELECT DISTINCT
            to_char(d, 'YYYYMMDD')::INTEGER,
            d,
            extract(day FROM d)::SMALLINT,
            extract(isodow FROM d)::SMALLINT,
            trim(to_char(d, 'Day')),
            extract(week FROM d)::SMALLINT,
            extract(month FROM d)::SMALLINT,
            trim(to_char(d, 'Month')),
            extract(quarter FROM d)::SMALLINT,
            extract(year FROM d)::SMALLINT,
            extract(isodow FROM d) IN (6, 7)
        FROM
        (
            SELECT transaction_timestamp::DATE AS d
            FROM raw.transactions
            WHERE source_transaction_id BETWEEN v_previous_watermark + 1 AND v_high_watermark
            UNION
            SELECT transaction_timestamp::DATE AS d
            FROM raw.laundering_pattern_transaction
            WHERE pattern_transaction_id BETWEEN v_previous_pattern_wm + 1 AND v_high_pattern_wm
        ) dates
        ON CONFLICT (date_key) DO NOTHING;

        -- Currency dimension (Type 1/static reference).
        INSERT INTO dw.dim_currency (currency_name)
        SELECT DISTINCT currency_name
        FROM
        (
            SELECT payment_currency AS currency_name
            FROM raw.transactions
            WHERE source_transaction_id BETWEEN v_previous_watermark + 1 AND v_high_watermark
            UNION
            SELECT receiving_currency
            FROM raw.transactions
            WHERE source_transaction_id BETWEEN v_previous_watermark + 1 AND v_high_watermark
            UNION
            SELECT payment_currency
            FROM raw.laundering_pattern_transaction
            WHERE pattern_transaction_id BETWEEN v_previous_pattern_wm + 1 AND v_high_pattern_wm
            UNION
            SELECT receiving_currency
            FROM raw.laundering_pattern_transaction
            WHERE pattern_transaction_id BETWEEN v_previous_pattern_wm + 1 AND v_high_pattern_wm
        ) c
        WHERE currency_name IS NOT NULL
        ON CONFLICT (currency_name) DO NOTHING;
        GET DIAGNOSTICS v_currency_rows = ROW_COUNT;

        -- Payment format dimension (Type 1/static reference).
        INSERT INTO dw.dim_payment_format (payment_format)
        SELECT DISTINCT payment_format
        FROM
        (
            SELECT payment_format
            FROM raw.transactions
            WHERE source_transaction_id BETWEEN v_previous_watermark + 1 AND v_high_watermark
            UNION
            SELECT payment_format
            FROM raw.laundering_pattern_transaction
            WHERE pattern_transaction_id BETWEEN v_previous_pattern_wm + 1 AND v_high_pattern_wm
        ) f
        WHERE payment_format IS NOT NULL
        ON CONFLICT (payment_format) DO NOTHING;
        GET DIAGNOSTICS v_format_rows = ROW_COUNT;

        -- Bank Type 1: bank_id ổn định, bank_name được cập nhật nếu source thay đổi.
        INSERT INTO dw.dim_bank (bank_id, bank_name, source_hash)
        SELECT
            a.bank_id,
            min(a.bank_name) AS bank_name,
            md5(concat_ws(chr(31), a.bank_id, min(a.bank_name))) AS source_hash
        FROM raw.account a
        GROUP BY a.bank_id
        ON CONFLICT (bank_id) DO UPDATE
        SET bank_name = EXCLUDED.bank_name,
            source_hash = EXCLUDED.source_hash,
            updated_at = clock_timestamp()
        WHERE dw.dim_bank.source_hash <> EXCLUDED.source_hash;
        GET DIAGNOSTICS v_bank_rows = ROW_COUNT;

        -- Entity Type 1; account giữ lịch sử quan hệ entity bằng SCD2.
        INSERT INTO dw.dim_entity (entity_id, entity_name, source_hash)
        SELECT
            a.entity_id,
            min(a.entity_name) AS entity_name,
            md5(concat_ws(chr(31), a.entity_id, coalesce(min(a.entity_name), ''))) AS source_hash
        FROM raw.account a
        WHERE a.entity_id IS NOT NULL
        GROUP BY a.entity_id
        ON CONFLICT (entity_id) DO UPDATE
        SET entity_name = EXCLUDED.entity_name,
            source_hash = EXCLUDED.source_hash,
            updated_at = clock_timestamp()
        WHERE dw.dim_entity.source_hash <> EXCLUDED.source_hash;
        GET DIAGNOSTICS v_entity_rows = ROW_COUNT;

        -- Snapshot account phục vụ so sánh hash SCD Type 2.
        TRUNCATE TABLE stg.account_snapshot;

        INSERT INTO stg.account_snapshot
            (bank_id, account_number, bank_key, entity_key, entity_id, source_hash)
        SELECT
            a.bank_id,
            a.account_number,
            b.bank_key,
            coalesce(e.entity_key, -1),
            a.entity_id,
            md5(concat_ws(chr(31), a.bank_id, a.account_number,
                          coalesce(a.entity_id, ''))) AS source_hash
        FROM raw.account a
        JOIN dw.dim_bank b ON b.bank_id = a.bank_id
        LEFT JOIN dw.dim_entity e ON e.entity_id = a.entity_id;

        UPDATE dw.dim_account d
        SET effective_to = v_started_at,
            is_current = FALSE,
            updated_at = clock_timestamp()
        FROM stg.account_snapshot s
        WHERE d.bank_id = s.bank_id
          AND d.account_number = s.account_number
          AND d.is_current
          AND d.account_key <> -1
          AND d.source_hash <> s.source_hash;
        GET DIAGNOSTICS v_rows = ROW_COUNT;
        v_account_rows := v_account_rows + v_rows;

        INSERT INTO dw.dim_account
            (bank_key, entity_key, bank_id, account_number, entity_id,
             source_hash, effective_from, effective_to, is_current)
        SELECT
            s.bank_key,
            s.entity_key,
            s.bank_id,
            s.account_number,
            s.entity_id,
            s.source_hash,
            v_started_at,
            '9999-12-31 23:59:59+00',
            TRUE
        FROM stg.account_snapshot s
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dw.dim_account d
            WHERE d.bank_id = s.bank_id
              AND d.account_number = s.account_number
              AND d.is_current
              AND d.source_hash = s.source_hash
        );
        GET DIAGNOSTICS v_rows = ROW_COUNT;
        v_account_rows := v_account_rows + v_rows;

        INSERT INTO dw.dim_pattern_type (pattern_type)
        SELECT DISTINCT pattern_type
        FROM raw.laundering_pattern_transaction
        WHERE pattern_transaction_id BETWEEN v_previous_pattern_wm + 1 AND v_high_pattern_wm
        ON CONFLICT (pattern_type) DO NOTHING;

        -- Transaction fact: role-playing dimensions cho sender và receiver.
        INSERT INTO dw.fact_transaction
        (
            transaction_key, source_transaction_id, date_key, time_key,
            from_bank_key, to_bank_key, from_account_key, to_account_key,
            from_entity_key, to_entity_key,
            payment_currency_key, receiving_currency_key, payment_format_key,
            amount_paid, amount_received, is_laundering,
            is_cross_bank, is_cross_currency, is_self_transfer,
            implied_exchange_rate, source_load_batch_id, dw_batch_id
        )
        SELECT
            t.source_transaction_id,
            t.source_transaction_id,
            coalesce(dd.date_key, -1),
            coalesce(dt.time_key, -1),
            coalesce(fb.bank_key, -1),
            coalesce(tb.bank_key, -1),
            coalesce(fa.account_key, -1),
            coalesce(ta.account_key, -1),
            coalesce(fa.entity_key, -1),
            coalesce(ta.entity_key, -1),
            coalesce(pc.currency_key, -1),
            coalesce(rc.currency_key, -1),
            coalesce(pf.payment_format_key, -1),
            t.amount_paid,
            t.amount_received,
            t.is_laundering,
            t.is_cross_bank,
            t.is_cross_currency,
            t.is_self_transfer,
            t.implied_exchange_rate,
            t.load_batch_id,
            v_batch_id
        FROM stg.v_transaction_enriched t
        LEFT JOIN dw.dim_date dd ON dd.date_key = t.date_key
        LEFT JOIN dw.dim_time dt ON dt.time_key = t.time_key
        LEFT JOIN dw.dim_bank fb ON fb.bank_id = t.from_bank_id
        LEFT JOIN dw.dim_bank tb ON tb.bank_id = t.to_bank_id
        LEFT JOIN dw.dim_account fa
            ON fa.bank_id = t.from_bank_id
           AND fa.account_number = t.from_account_id
           AND fa.is_current
        LEFT JOIN dw.dim_account ta
            ON ta.bank_id = t.to_bank_id
           AND ta.account_number = t.to_account_id
           AND ta.is_current
        LEFT JOIN dw.dim_currency pc ON pc.currency_name = t.payment_currency
        LEFT JOIN dw.dim_currency rc ON rc.currency_name = t.receiving_currency
        LEFT JOIN dw.dim_payment_format pf ON pf.payment_format = t.payment_format
        WHERE t.source_transaction_id BETWEEN v_previous_watermark + 1 AND v_high_watermark
        ON CONFLICT (transaction_key) DO NOTHING;
        GET DIAGNOSTICS v_fact_rows = ROW_COUNT;

        INSERT INTO dw.fact_pattern_transaction
        (
            pattern_transaction_key, source_pattern_transaction_id,
            pattern_attempt_id, pattern_type_key, pattern_sequence,
            pattern_description, date_key, time_key,
            from_bank_key, to_bank_key, from_account_key, to_account_key,
            payment_currency_key, receiving_currency_key, payment_format_key,
            amount_paid, amount_received, is_laundering,
            source_load_batch_id, dw_batch_id
        )
        SELECT
            p.pattern_transaction_id,
            p.pattern_transaction_id,
            p.pattern_attempt_id,
            coalesce(pt.pattern_type_key, -1),
            p.pattern_sequence,
            p.pattern_description,
            coalesce(dd.date_key, -1),
            coalesce(dt.time_key, -1),
            coalesce(fb.bank_key, -1),
            coalesce(tb.bank_key, -1),
            coalesce(fa.account_key, -1),
            coalesce(ta.account_key, -1),
            coalesce(pc.currency_key, -1),
            coalesce(rc.currency_key, -1),
            coalesce(pf.payment_format_key, -1),
            p.amount_paid,
            p.amount_received,
            p.is_laundering,
            p.load_batch_id,
            v_batch_id
        FROM stg.v_pattern_enriched p
        LEFT JOIN dw.dim_pattern_type pt ON pt.pattern_type = p.pattern_type
        LEFT JOIN dw.dim_date dd ON dd.date_key = p.date_key
        LEFT JOIN dw.dim_time dt ON dt.time_key = p.time_key
        LEFT JOIN dw.dim_bank fb ON fb.bank_id = p.from_bank_id
        LEFT JOIN dw.dim_bank tb ON tb.bank_id = p.to_bank_id
        LEFT JOIN dw.dim_account fa
            ON fa.bank_id = p.from_bank_id
           AND fa.account_number = p.from_account_id
           AND fa.is_current
        LEFT JOIN dw.dim_account ta
            ON ta.bank_id = p.to_bank_id
           AND ta.account_number = p.to_account_id
           AND ta.is_current
        LEFT JOIN dw.dim_currency pc ON pc.currency_name = p.payment_currency
        LEFT JOIN dw.dim_currency rc ON rc.currency_name = p.receiving_currency
        LEFT JOIN dw.dim_payment_format pf ON pf.payment_format = p.payment_format
        WHERE p.pattern_transaction_id BETWEEN v_previous_pattern_wm + 1 AND v_high_pattern_wm
        ON CONFLICT (pattern_transaction_key) DO NOTHING;
        GET DIAGNOSTICS v_pattern_rows = ROW_COUNT;

        -- Những lookup không thành công vẫn vào fact với Unknown key và được ghi reject.
        INSERT INTO etl.dw_rejected_row
            (dw_batch_id, source_object, source_key, error_code,
             error_description, raw_payload)
        SELECT
            v_batch_id,
            'raw.transactions',
            f.source_transaction_id,
            'UNKNOWN_DIMENSION_KEY',
            'Một hoặc nhiều dimension lookup trả về Unknown key (-1)',
            jsonb_build_object(
                'date_key', f.date_key,
                'time_key', f.time_key,
                'from_bank_key', f.from_bank_key,
                'to_bank_key', f.to_bank_key,
                'from_account_key', f.from_account_key,
                'to_account_key', f.to_account_key,
                'payment_currency_key', f.payment_currency_key,
                'receiving_currency_key', f.receiving_currency_key,
                'payment_format_key', f.payment_format_key
            )
        FROM dw.fact_transaction f
        WHERE f.dw_batch_id = v_batch_id
          AND (
              f.date_key = -1 OR f.time_key = -1
              OR f.from_bank_key = -1 OR f.to_bank_key = -1
              OR f.from_account_key = -1 OR f.to_account_key = -1
              OR f.payment_currency_key = -1 OR f.receiving_currency_key = -1
              OR f.payment_format_key = -1
          );

        INSERT INTO etl.dw_rejected_row
            (dw_batch_id, source_object, source_key, error_code,
             error_description, raw_payload)
        SELECT
            v_batch_id,
            'raw.laundering_pattern_transaction',
            f.source_pattern_transaction_id,
            'UNKNOWN_DIMENSION_KEY',
            'Một hoặc nhiều dimension lookup của pattern trả về Unknown key (-1)',
            jsonb_build_object('pattern_attempt_id', f.pattern_attempt_id,
                               'pattern_sequence', f.pattern_sequence)
        FROM dw.fact_pattern_transaction f
        WHERE f.dw_batch_id = v_batch_id
          AND (
              f.pattern_type_key = -1 OR f.date_key = -1 OR f.time_key = -1
              OR f.from_bank_key = -1 OR f.to_bank_key = -1
              OR f.from_account_key = -1 OR f.to_account_key = -1
              OR f.payment_currency_key = -1 OR f.receiving_currency_key = -1
              OR f.payment_format_key = -1
          );

        SELECT count(*) INTO v_rejected_rows
        FROM etl.dw_rejected_row
        WHERE dw_batch_id = v_batch_id;

        TRUNCATE TABLE stg.account_snapshot;

        UPDATE etl.dw_batch
        SET status = 'COMPLETED',
            completed_at = clock_timestamp(),
            bank_rows_affected = v_bank_rows,
            entity_rows_affected = v_entity_rows,
            account_rows_affected = v_account_rows,
            currency_rows_affected = v_currency_rows,
            payment_format_rows_affected = v_format_rows,
            transaction_rows_inserted = v_fact_rows,
            pattern_rows_inserted = v_pattern_rows,
            rejected_rows = v_rejected_rows
        WHERE dw_batch_id = v_batch_id;

        RAISE NOTICE 'DW batch % COMPLETED: % transactions, % patterns, % rejects',
            v_batch_id, v_fact_rows, v_pattern_rows, v_rejected_rows;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;

        UPDATE etl.dw_batch
        SET status = 'FAILED',
            completed_at = clock_timestamp(),
            error_message = v_error
        WHERE dw_batch_id = v_batch_id;

        RAISE WARNING 'DW batch % FAILED: %', v_batch_id, v_error;
    END;
END;
$$;

CREATE OR REPLACE PROCEDURE etl.validate_dw()
LANGUAGE plpgsql
AS $$
DECLARE
    v_batch_id             BIGINT;
    s_transactions         BIGINT;
    s_patterns             BIGINT;
    s_accounts             BIGINT;
    s_laundering           BIGINT;
    s_cross_bank           BIGINT;
    s_cross_currency       BIGINT;
    s_self_transfer        BIGINT;
    d_transactions         BIGINT;
    d_patterns             BIGINT;
    d_accounts             BIGINT;
    d_laundering           BIGINT;
    d_cross_bank           BIGINT;
    d_cross_currency       BIGINT;
    d_self_transfer        BIGINT;
    d_unknown              BIGINT;
    v_currency_mismatches  BIGINT;
    v_failed               BIGINT;
BEGIN
    SELECT max(dw_batch_id) INTO v_batch_id
    FROM etl.dw_batch
    WHERE status = 'COMPLETED';

    IF v_batch_id IS NULL THEN
        RAISE EXCEPTION 'Chưa có DW batch COMPLETED để validation';
    END IF;

    DELETE FROM etl.dw_validation_result WHERE dw_batch_id = v_batch_id;

    SELECT
        count(*),
        count(*) FILTER (WHERE is_laundering),
        count(*) FILTER (WHERE from_bank_id <> to_bank_id),
        count(*) FILTER (WHERE payment_currency <> receiving_currency),
        count(*) FILTER (
            WHERE from_bank_id = to_bank_id AND from_account_id = to_account_id)
    INTO s_transactions, s_laundering, s_cross_bank,
         s_cross_currency, s_self_transfer
    FROM raw.transactions;

    SELECT count(*) INTO s_patterns FROM raw.laundering_pattern_transaction;
    SELECT count(*) INTO s_accounts FROM raw.account;

    SELECT
        count(*),
        count(*) FILTER (WHERE is_laundering),
        count(*) FILTER (WHERE is_cross_bank),
        count(*) FILTER (WHERE is_cross_currency),
        count(*) FILTER (WHERE is_self_transfer),
        count(*) FILTER (
            WHERE date_key = -1 OR time_key = -1
               OR from_bank_key = -1 OR to_bank_key = -1
               OR from_account_key = -1 OR to_account_key = -1
               OR payment_currency_key = -1 OR receiving_currency_key = -1
               OR payment_format_key = -1)
    INTO d_transactions, d_laundering, d_cross_bank,
         d_cross_currency, d_self_transfer, d_unknown
    FROM dw.fact_transaction;

    SELECT count(*) INTO d_patterns FROM dw.fact_pattern_transaction;
    SELECT count(*) INTO d_accounts
    FROM dw.dim_account
    WHERE is_current AND account_key <> -1;

    WITH source_amount AS
    (
        SELECT payment_currency AS currency_name,
               count(*) AS row_count,
               sum(amount_paid) AS total_amount
        FROM raw.transactions
        GROUP BY payment_currency
    ),
    dw_amount AS
    (
        SELECT c.currency_name,
               count(*) AS row_count,
               sum(f.amount_paid) AS total_amount
        FROM dw.fact_transaction f
        JOIN dw.dim_currency c ON c.currency_key = f.payment_currency_key
        GROUP BY c.currency_name
    )
    SELECT count(*) INTO v_currency_mismatches
    FROM source_amount s
    FULL JOIN dw_amount d USING (currency_name)
    WHERE s.row_count IS DISTINCT FROM d.row_count
       OR s.total_amount IS DISTINCT FROM d.total_amount;

    INSERT INTO etl.dw_validation_result
        (dw_batch_id, check_name, source_value, target_value, status, details)
    VALUES
        (v_batch_id, 'TRANSACTION_ROW_COUNT', s_transactions, d_transactions,
         CASE WHEN s_transactions = d_transactions THEN 'PASSED' ELSE 'FAILED' END,
         'Grain 1 source transaction = 1 fact row'),
        (v_batch_id, 'PATTERN_ROW_COUNT', s_patterns, d_patterns,
         CASE WHEN s_patterns = d_patterns THEN 'PASSED' ELSE 'FAILED' END,
         'Grain 1 pattern transaction = 1 pattern fact row'),
        (v_batch_id, 'CURRENT_ACCOUNT_COUNT', s_accounts, d_accounts,
         CASE WHEN s_accounts = d_accounts THEN 'PASSED' ELSE 'FAILED' END,
         'Không tính Unknown account'),
        (v_batch_id, 'LAUNDERING_COUNT', s_laundering, d_laundering,
         CASE WHEN s_laundering = d_laundering THEN 'PASSED' ELSE 'FAILED' END,
         'is_laundering giữ nguyên ground truth'),
        (v_batch_id, 'CROSS_BANK_COUNT', s_cross_bank, d_cross_bank,
         CASE WHEN s_cross_bank = d_cross_bank THEN 'PASSED' ELSE 'FAILED' END,
         'from_bank_id khác to_bank_id'),
        (v_batch_id, 'CROSS_CURRENCY_COUNT', s_cross_currency, d_cross_currency,
         CASE WHEN s_cross_currency = d_cross_currency THEN 'PASSED' ELSE 'FAILED' END,
         'payment_currency khác receiving_currency'),
        (v_batch_id, 'SELF_TRANSFER_COUNT', s_self_transfer, d_self_transfer,
         CASE WHEN s_self_transfer = d_self_transfer THEN 'PASSED' ELSE 'FAILED' END,
         'Cùng bank và account'),
        (v_batch_id, 'UNKNOWN_DIMENSION_LOOKUP', 0, d_unknown,
         CASE WHEN d_unknown = 0 THEN 'PASSED' ELSE 'FAILED' END,
         'Fact không được dùng Unknown key với dataset hiện tại'),
        (v_batch_id, 'PAYMENT_AMOUNT_BY_CURRENCY', 0, v_currency_mismatches,
         CASE WHEN v_currency_mismatches = 0 THEN 'PASSED' ELSE 'FAILED' END,
         'Số dòng và total amount_paid được so sánh riêng từng currency');

    SELECT count(*) INTO v_failed
    FROM etl.dw_validation_result
    WHERE dw_batch_id = v_batch_id AND status = 'FAILED';

    UPDATE etl.dw_batch
    SET validation_status = CASE WHEN v_failed = 0 THEN 'PASSED' ELSE 'FAILED' END
    WHERE dw_batch_id = v_batch_id;

    RAISE NOTICE 'Validation batch %: %', v_batch_id,
        CASE WHEN v_failed = 0 THEN 'PASSED' ELSE 'FAILED' END;
END;
$$;

