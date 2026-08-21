/*
CẢNH BÁO: script tùy chọn, phá hủy toàn bộ dữ liệu DW để chạy lại từ đầu.
Không chạy trong quy trình bình thường và không chạy nhầm trên production.
Database nguồn raw.* không bị xóa.
*/

BEGIN;

TRUNCATE TABLE
    dw.fact_pattern_transaction,
    dw.fact_transaction,
    stg.account_snapshot,
    etl.dw_validation_result,
    etl.dw_rejected_row,
    etl.dw_batch
RESTART IDENTITY CASCADE;

TRUNCATE TABLE
    dw.dim_account,
    dw.dim_pattern_type,
    dw.dim_payment_format,
    dw.dim_currency,
    dw.dim_entity,
    dw.dim_bank
RESTART IDENTITY CASCADE;

DELETE FROM dw.dim_date WHERE date_key <> -1;
DELETE FROM dw.dim_time WHERE time_key <> -1;

COMMIT;

-- Sau reset, chạy lại 01_create_dw_tables.sql để tái tạo Unknown rows và dim_time.

