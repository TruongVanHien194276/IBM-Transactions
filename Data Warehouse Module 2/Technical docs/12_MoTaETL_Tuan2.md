# Mô tả ETL tuần 2 – PostgreSQL Source to Data Warehouse

## 1. Kiến trúc

```text
raw.account / raw.transactions / raw.laundering_pattern_transaction
                              ↓
             stg views + account snapshot
                              ↓
          dimension lookup và SCD Type 2
                              ↓
        dw.fact_transaction / fact_pattern_transaction
                              ↓
         reconciliation + materialized data mart
```

## 2. Batch và watermark

- Mỗi lần chạy tạo một dòng `etl.dw_batch` trạng thái `STARTED`.
- FULL đặt watermark trước bằng 0 và đọc toàn bộ source.
- INCREMENTAL lấy watermark lớn nhất của batch `COMPLETED` gần nhất.
- High watermark được khóa bằng `max(source_transaction_id)` tại đầu batch.
- Fact chỉ lấy ID trong khoảng low–high của batch.
- Batch thành công chuyển sang `COMPLETED`; lỗi chuyển `FAILED` và lưu message.
- PostgreSQL advisory lock ngăn hai ETL chạy đồng thời.

## 3. Dimension load

- Date và time được suy ra từ `transaction_timestamp`.
- Currency, payment format và pattern type dùng insert distinct + conflict handling.
- Bank và entity dùng Type 1 UPSERT dựa trên MD5 source hash.
- Account được đưa vào `stg.account_snapshot`.
- Nếu hash account thay đổi, version hiện tại được đóng bằng `effective_to`.
- Version mới được thêm với `is_current = true`.

## 4. Fact load

- Lookup hai role bank, account, entity và currency.
- Giữ cả paid amount lẫn received amount cùng currency key tương ứng.
- Tạo cross-bank, cross-currency, self-transfer và implied exchange rate.
- Dùng `ON CONFLICT DO NOTHING` trên source key để chạy lại không duplicate.
- Lookup không thành công dùng Unknown key `-1` và ghi reject.

## 5. Reconciliation

`etl.validate_dw()` kiểm tra:

- Transaction row count.
- Pattern transaction row count.
- Current account count.
- Laundering count.
- Cross-bank count.
- Cross-currency count.
- Self-transfer count.
- Unknown dimension lookup.
- Số dòng và tổng amount paid theo từng currency.

Chỉ khi tất cả check `PASSED`, batch mới có `validation_status = PASSED`.

## 6. Idempotency

- Chạy FULL lần hai không nhân đôi fact.
- Chạy INCREMENTAL khi source không đổi sẽ insert 0 fact row.
- Dimension reference có unique business key.
- Account chỉ có một current version cho mỗi business key.
- Materialized view được refresh sau batch thành công.

## 7. Hiệu năng

- Source transaction có unique index trên watermark ID.
- Index fact được tạo sau initial load.
- BRIN dùng cho cột có khối lượng lớn và tương quan vật lý.
- Partial index chỉ lưu transaction laundering.
- Mart tổng hợp trước để Power BI không quét fact cho từng visual.
- Chạy `ANALYZE` sau full load và sau khi tạo mart.

