/*
Tuần 4 - Các truy vấn ngắn dùng khi demo/bảo vệ
Mỗi result set trả lời một câu hỏi thường gặp của giảng viên.
*/

\set ON_ERROR_STOP on
\pset pager off

-- A. Trạng thái nghiệm thu mới nhất.
SELECT
    test_run_id,
    completed_at,
    test_count,
    passed_count,
    failed_count,
    status
FROM qa.v_week4_latest_run;

-- B. Các test chưa đạt. Kết quả kỳ vọng: 0 dòng.
SELECT
    category,
    test_code,
    test_name,
    expected_value,
    actual_value,
    details
FROM qa.v_week4_latest_results
WHERE status = 'FAILED';

-- C. KPI chính, không cộng lẫn amount của nhiều currency.
SELECT *
FROM pbi.kpi_overview;

-- D. Lịch sử ETL và bằng chứng incremental idempotent.
SELECT
    dw_batch_id,
    load_type,
    status,
    started_at,
    completed_at,
    duration_minutes,
    transaction_rows_inserted,
    pattern_rows_inserted,
    rejected_rows,
    validation_status
FROM pbi.etl_batch_monitor
ORDER BY dw_batch_id;

-- E. Chất lượng dữ liệu và validation gần nhất.
SELECT *
FROM pbi.data_quality_overview;

SELECT
    dw_batch_id,
    check_name,
    source_value,
    target_value,
    difference_value,
    status
FROM pbi.etl_validation_result
WHERE dw_batch_id =
(
    SELECT max(dw_batch_id)
    FROM pbi.etl_batch_monitor
)
ORDER BY validation_result_id;

-- F. Laundering rate theo payment format.
SELECT
    p.payment_format,
    f.transaction_count,
    f.laundering_count,
    f.laundering_rate_percent
FROM pbi.fact_aml_payment_format f
JOIN pbi.dim_payment_format p
  ON p.payment_format_key = f.payment_format_key
ORDER BY f.laundering_rate_percent DESC;

-- G. Các pattern có số attempt lớn nhất.
SELECT
    p.pattern_type,
    f.attempt_count,
    f.pattern_transaction_count,
    f.min_sequence,
    f.max_sequence
FROM pbi.fact_pattern_summary f
JOIN pbi.dim_pattern_type p
  ON p.pattern_type_key = f.pattern_type_key
ORDER BY f.attempt_count DESC;
