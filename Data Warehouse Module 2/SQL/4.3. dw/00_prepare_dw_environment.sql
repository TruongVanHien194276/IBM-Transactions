/*
Chạy trong connection trỏ tới database aml_source
Tạo ranh giới logic cho staging, data warehouse và data mart
*/

DO $$
BEGIN
    IF current_database() <> 'aml_source' THEN
        RAISE EXCEPTION 'Sai database: hãy đổi connection sang aml_source trước khi chạy';
    END IF;
END
$$;

CREATE SCHEMA IF NOT EXISTS stg;
CREATE SCHEMA IF NOT EXISTS dw;
CREATE SCHEMA IF NOT EXISTS mart;

-- Identity này là khóa kỹ thuật ổn định và watermark của transaction source.
CREATE UNIQUE INDEX IF NOT EXISTS ux_raw_transactions_source_transaction_id
    ON raw.transactions (source_transaction_id);

COMMENT ON SCHEMA stg IS 'Lớp chuẩn hóa và snapshot tạm phục vụ ETL Data Warehouse';
COMMENT ON SCHEMA dw IS 'Dimensional Data Warehouse cho IBM AML HI-Medium';
COMMENT ON SCHEMA mart IS 'Các bảng tổng hợp/materialized view phục vụ Power BI';
