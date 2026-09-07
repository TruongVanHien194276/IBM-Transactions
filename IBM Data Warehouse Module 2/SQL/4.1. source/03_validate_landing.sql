/* Dừng quy trình nếu 1 trong 3 file chưa được nạp đủ */

SELECT 'account_landing' AS source_object, count(*) AS row_count
FROM raw.account_landing
UNION ALL
SELECT 'transaction_landing', count(*)
FROM raw.transaction_landing
UNION ALL
SELECT 'pattern_transaction_landing', count(*)
FROM raw.pattern_transaction_landing;

DO $$
DECLARE
    v_account_rows BIGINT;
    v_transaction_rows BIGINT;
    v_pattern_rows BIGINT;
BEGIN
    SELECT count(*) INTO v_account_rows FROM raw.account_landing;
    SELECT count(*) INTO v_transaction_rows FROM raw.transaction_landing;
    SELECT count(*) INTO v_pattern_rows FROM raw.pattern_transaction_landing;

    IF v_account_rows <> 2087786 THEN
        RAISE EXCEPTION 'Account landing sai số dòng: %, kỳ vọng 2087786', v_account_rows;
    END IF;

    IF v_transaction_rows <> 31898238 THEN
        RAISE EXCEPTION 'Transaction landing sai số dòng: %, kỳ vọng 31898238', v_transaction_rows;
    END IF;

    IF v_pattern_rows <> 22743 THEN
        RAISE EXCEPTION 'Pattern landing sai số dòng: %, kỳ vọng 22743', v_pattern_rows;
    END IF;
END
$$;

SELECT * FROM raw.account_landing ORDER BY landing_row_id LIMIT 5;
SELECT * FROM raw.transaction_landing ORDER BY landing_row_id LIMIT 5;
SELECT * FROM raw.pattern_transaction_landing ORDER BY landing_row_id LIMIT 5;
