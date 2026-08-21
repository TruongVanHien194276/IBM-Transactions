/*
Initial/full load. Có thể chạy lại an toàn: fact không bị nhân đôi
Thời gian phụ thuộc máy vì phải xử lý 31,9 triệu giao dịch
*/

CALL etl.load_dw('FULL');

SELECT
    dw_batch_id,
    load_type,
    status,
    started_at,
    completed_at,
    source_low_watermark,
    source_high_watermark,
    transaction_rows_inserted,
    pattern_rows_inserted,
    rejected_rows,
    error_message
FROM etl.dw_batch
ORDER BY dw_batch_id DESC
LIMIT 1;

