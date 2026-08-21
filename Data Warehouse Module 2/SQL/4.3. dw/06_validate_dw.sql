/*
Đối soát source với Data Warehouse và xuất kết quả PASS/FAIL
*/

CALL etl.validate_dw();

SELECT
    b.dw_batch_id,
    b.load_type,
    b.status AS etl_status,
    b.validation_status,
    b.started_at,
    b.completed_at,
    b.transaction_rows_inserted,
    b.pattern_rows_inserted,
    b.rejected_rows
FROM etl.dw_batch b
WHERE b.status = 'COMPLETED'
ORDER BY b.dw_batch_id DESC
LIMIT 1;

SELECT
    check_name,
    source_value,
    target_value,
    status,
    details,
    checked_at
FROM etl.dw_validation_result
WHERE dw_batch_id =
(
    SELECT max(dw_batch_id)
    FROM etl.dw_batch
    WHERE status = 'COMPLETED'
)
ORDER BY validation_result_id;

SELECT * FROM mart.mv_kpi_overview;

