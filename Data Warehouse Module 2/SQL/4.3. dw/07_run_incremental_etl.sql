/*
Chạy sau khi source có dữ liệu mới. Nếu không có dữ liệu mới, batch vẫn
COMPLETED với transaction_rows_inserted = 0 và không phát sinh duplicate
*/

CALL etl.load_dw('INCREMENTAL');

SELECT
    dw_batch_id,
    load_type,
    status,
    source_low_watermark,
    source_high_watermark,
    transaction_rows_inserted,
    pattern_rows_inserted,
    rejected_rows,
    error_message
FROM etl.dw_batch
ORDER BY dw_batch_id DESC
LIMIT 1;

-- Chỉ refresh mart khi batch ở trên COMPLETED.
CALL mart.refresh_all();
CALL etl.validate_dw();

