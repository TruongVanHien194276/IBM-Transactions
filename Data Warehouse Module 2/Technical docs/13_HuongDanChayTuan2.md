# Hướng dẫn chạy đầy đủ tuần 2 bằng PostgreSQL và DBeaver trên macOS

## 1. Kết quả phải đạt

Sau khi hoàn thành tuần 2, database `aml_source` phải có:

- Schema `stg` cho lớp chuẩn hóa ETL.
- Schema `dw` chứa dimension và fact.
- Schema `mart` chứa materialized view phục vụ Power BI.
- Audit batch FULL/INCREMENTAL trong `etl.dw_batch`.
- SCD Type 2 cho account.
- `31.898.238` dòng `dw.fact_transaction`.
- `22.743` dòng `dw.fact_pattern_transaction`.
- `2.087.786` current account dimension, không tính Unknown row.
- `0` rejected row và `0` fact dùng Unknown key.
- Tất cả validation check có trạng thái `PASSED`.

## 2. Kiến trúc sử dụng

Project giữ source và Data Warehouse trong cùng database PostgreSQL `aml_source`, nhưng tách schema:

```text
raw    = database nguồn đã hoàn thành tuần 1
stg    = staging/view/temporary snapshot của ETL tuần 2
dw     = dimension và fact
mart   = materialized view cho Power BI
etl    = batch log, reject và validation
```

## 3. Điều kiện trước khi chạy

### 3.1 Kiểm tra PostgreSQL

Mở Terminal và chạy:

```bash
brew services list | grep postgresql
pg_isready -h localhost -p 5432
```

Kết quả:

```text
postgresql@17 started
localhost:5432 - accepting connections
```

### 3.2 Kết nối DBeaver

Sử dụng connection:

```text
Driver: PostgreSQL
Host: localhost
Port: 5432
Database: aml_source
Username: hoangyugi001
Password: để trống theo cấu hình local hiện tại
```

### 3.3 Kiểm tra đang ở đúng database

Trong DBeaver:

- Nhấp phải connection `aml_source`.
- Chọn **SQL Editor → New SQL Script**.
- Chạy câu lệnh:

```sql
SELECT current_database(), current_user;
```

Kết quả

```text
aml_source | hoangyugi001
```

### 3.4 Kiểm tra tuần 1

Chạy:

```sql
SELECT
    (SELECT count(*) FROM raw.account) AS accounts,
    (SELECT count(*) FROM raw.transactions) AS transactions,
    (SELECT count(*) FROM raw.laundering_pattern_transaction) AS pattern_transactions,
    (SELECT count(*) FROM raw.rejected_row) AS rejected_rows;
```

Kết quả:

```text
accounts             = 2087786
transactions         = 31898238
pattern_transactions = 22743
rejected_rows        = 0
```

Nếu số liệu khác, dừng tuần 2 và chạy lại validation tuần 1.

## 4. Cách mở và chạy một file SQL trong DBeaver

Áp dụng cho tất cả file bên dưới:

1. Chọn **File → Open File**.
2. Mở file trong thư mục:

```text
/Users/hoangyugi001/Documents/Coder/IBM Transactions/sql/03_dw/
```

3. Kiểm tra thanh connection phía trên editor đang là `aml_source`.
4. Không bôi đen riêng một phần nếu hướng dẫn yêu cầu chạy cả file.
5. Chọn **SQL Editor → Execute SQL Script**.
6. Phím tắt trên macOS thường là `Option + X`.
7. Xem tab **Output** và **Results** ở dưới.

Khuyến nghị bật Auto-commit khi chạy các file tuần 2. Không đóng DBeaver hoặc cho Mac sleep trong lúc full load.

## 5. Bước 1 – Chuẩn bị môi trường DW

Mở và chạy:

```text
sql/03_dw/00_prepare_dw_environment.sql
```

Script thực hiện:

- Kiểm tra database phải là `aml_source`.
- Tạo schema `stg`, `dw`, `mart`.
- Tạo unique index cho `raw.transactions.source_transaction_id`.
- Index này bảo đảm source watermark là duy nhất.

Lần đầu tạo index trên 31,9 triệu dòng có thể mất thời gian. Không hủy nếu DBeaver vẫn đang chạy.

Kiểm tra:

```sql
SELECT schema_name
FROM information_schema.schemata
WHERE schema_name IN ('stg', 'dw', 'mart')
ORDER BY schema_name;
```

Phải thấy ba dòng `dw`, `mart`, `stg`.

## 6. Bước 2 – Tạo dimension, fact và staging

Mở và chạy:

```text
sql/03_dw/01_create_dw_tables.sql
```

Script tạo:

- `etl.dw_batch`
- `etl.dw_rejected_row`
- `etl.dw_validation_result`
- `dw.dim_date`
- `dw.dim_time`
- `dw.dim_currency`
- `dw.dim_payment_format`
- `dw.dim_bank`
- `dw.dim_entity`
- `dw.dim_account`
- `dw.dim_pattern_type`
- `dw.fact_transaction`
- `dw.fact_pattern_transaction`
- `stg.account_snapshot`
- `stg.v_transaction_enriched`
- `stg.v_pattern_enriched`

Script đồng thời tạo Unknown member `-1` và sinh `1.440` phút trong `dim_time`.

Kiểm tra:

```sql
SELECT
    (SELECT count(*) FROM dw.dim_time) AS time_rows,
    (SELECT count(*) FROM dw.dim_bank WHERE bank_key = -1) AS unknown_bank,
    (SELECT count(*) FROM dw.dim_account WHERE account_key = -1) AS unknown_account;
```

Kết quả:

```text
time_rows       = 1441
unknown_bank    = 1
unknown_account = 1
```

`1441` gồm 1.440 phút và một Unknown time

## 7. Bước 3 – Tạo ETL procedure

Mở và chạy:

```text
sql/03_dw/02_create_etl_procedures.sql
```

Script tạo hai procedure:

- `etl.load_dw(load_type)`
- `etl.validate_dw()`

Kiểm tra:

```sql
SELECT routine_schema, routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'etl'
  AND routine_name IN ('load_dw', 'validate_dw')
ORDER BY routine_name;
```

Phải thấy hai dòng có `routine_type = PROCEDURE`.

## 8. Bước 4 – Chạy FULL ETL

Mở và chạy toàn bộ:

```text
sql/03_dw/03_run_full_etl.sql
```

Lệnh quan trọng bên trong là:

```sql
CALL etl.load_dw('FULL');
```

ETL thực hiện theo thứ tự:

1. Khóa advisory để không chạy trùng ETL.
2. Tạo audit batch `STARTED`.
3. Khóa source high watermark.
4. Load Date, Currency và Payment Format.
5. Load Bank và Entity Type 1.
6. Tạo account snapshot.
7. So sánh hash và xử lý Account SCD Type 2.
8. Lookup dimension cho sender và receiver.
9. Nạp `fact_transaction`.
10. Nạp pattern dimension và pattern fact.
11. Ghi reject nếu dimension lookup thất bại.
12. Dọn staging snapshot.
13. Chuyển batch sang `COMPLETED`.

### 8.1 Trong lúc ETL chạy

- Đây là bước lâu nhất vì xử lý `31.898.238` transaction.
- Không bấm Stop trừ khi PostgreSQL báo lỗi rõ ràng.
- Không đóng nắp Mac hoặc để máy sleep.
- Có thể mở một connection DBeaver khác và chạy:

```sql
SELECT
    pid,
    state,
    wait_event_type,
    wait_event,
    now() - query_start AS elapsed,
    left(query, 100) AS current_query
FROM pg_stat_activity
WHERE datname = 'aml_source'
  AND state <> 'idle';
```

`state = active` và wait event trống nghĩa là PostgreSQL đang xử lý CPU bình thường.

### 8.2 Kiểm tra batch sau khi hoàn thành

```sql
SELECT *
FROM etl.dw_batch
ORDER BY dw_batch_id DESC
LIMIT 1;
```

Kết quả:

```text
load_type                 = FULL
status                    = COMPLETED
source_low_watermark      = 1
source_high_watermark     = 31898238
transaction_rows_inserted = 31898238
pattern_rows_inserted     = 22743
rejected_rows             = 0
error_message             = NULL
```

Nếu status là `FAILED`, đọc `error_message` trước khi chạy lại. FULL load có tính idempotent nên chạy lại không tạo duplicate

## 9. Bước 5 – Tạo index và cập nhật statistics

Chỉ chạy sau khi FULL ETL hoàn thành:

```text
sql/03_dw/04_create_dw_indexes.sql
```

Script tạo:

- BRIN index cho fact lớn.
- Index theo date, paid currency và payment format.
- Partial index chỉ cho laundering transactions.
- Index cho pattern fact, batch và reject.
- `ANALYZE` dimension/fact.

Kiểm tra index:

```sql
SELECT indexname
FROM pg_indexes
WHERE schemaname = 'dw'
  AND tablename = 'fact_transaction'
ORDER BY indexname;
```

Phải thấy primary/unique index và các index bắt đầu bằng `ix_fact_transaction_`.

## 10. Bước 6 – Tạo Data Mart

Mở và chạy:

```text
sql/03_dw/05_create_data_marts.sql
```

Script tạo và populate bảy materialized view:

- `mart.mv_kpi_overview`
- `mart.mv_daily_transaction`
- `mart.mv_aml_by_payment_format`
- `mart.mv_bank_activity`
- `mart.mv_currency_flow`
- `mart.mv_pattern_summary`
- `mart.mv_aml_account_risk`

Kiểm tra:

```sql
SELECT schemaname, matviewname, ispopulated
FROM pg_matviews
WHERE schemaname = 'mart'
ORDER BY matviewname;
```

Tất cả phải có `ispopulated = true`.

## 11. Bước 7 – Validation và reconciliation

Mở và chạy:

```text
sql/03_dw/06_validate_dw.sql
```

Script gọi `etl.validate_dw()` và hiển thị kết quả.

Tất cả check sau phải `PASSED`:

```text
TRANSACTION_ROW_COUNT
PATTERN_ROW_COUNT
CURRENT_ACCOUNT_COUNT
LAUNDERING_COUNT
CROSS_BANK_COUNT
CROSS_CURRENCY_COUNT
SELF_TRANSFER_COUNT
UNKNOWN_DIMENSION_LOOKUP
PAYMENT_AMOUNT_BY_CURRENCY
```

Các số liệu khóa sổ:

```text
Fact transactions          = 31.898.238
Pattern fact rows          = 22.743
Current accounts           = 2.087.786
Laundering transactions    = 35.230
Cross-bank transactions    = 29.092.624
Cross-currency transactions= 485.144
Self-transfers             = 2.561.860
Unknown fact lookup        = 0
Rejected rows              = 0
```

Kiểm tra batch:

```sql
SELECT dw_batch_id, status, validation_status
FROM etl.dw_batch
ORDER BY dw_batch_id DESC
LIMIT 1;
```

Kết quả cuối phải là:

```text
status            = COMPLETED
validation_status = PASSED
```

## 12. Bước 8 – Kiểm tra các báo cáo mẫu

### KPI tổng quan

```sql
SELECT * FROM mart.mv_kpi_overview;
```

### AML theo payment format

```sql
SELECT *
FROM mart.mv_aml_by_payment_format
ORDER BY laundering_rate_percent DESC;
```

### Ngân hàng hoạt động nhiều nhất

```sql
SELECT *
FROM mart.mv_bank_activity
ORDER BY total_participations DESC
LIMIT 20;
```

### Luồng currency

```sql
SELECT *
FROM mart.mv_currency_flow
ORDER BY transaction_count DESC
LIMIT 20;
```

### Pattern summary

```sql
SELECT *
FROM mart.mv_pattern_summary
ORDER BY pattern_transaction_count DESC;
```

### Account tham gia nhiều laundering transaction

```sql
SELECT *
FROM mart.mv_aml_account_risk
ORDER BY laundering_participations DESC
LIMIT 20;
```

## 13. Bước 9 – Kiểm tra incremental và idempotency

Khi source chưa có dữ liệu mới, mở và chạy:

```text
sql/03_dw/07_run_incremental_etl.sql
```

Kết quả:

```text
load_type                 = INCREMENTAL
status                    = COMPLETED
transaction_rows_inserted = 0
pattern_rows_inserted     = 0
rejected_rows             = 0
```

Fact row count vẫn phải là `31.898.238`; điều này chứng minh chạy lại không tạo duplicate

Khi có source mới, procedure chỉ lấy ID lớn hơn watermark của batch `COMPLETED` gần nhất

## 14. Làm mới Data Mart sau ETL

Nếu tự gọi ETL thay vì chạy file 07, sau batch `COMPLETED` chạy:

```sql
CALL mart.refresh_all();
CALL etl.validate_dw();
```

Không refresh mart sau một batch `FAILED`

## 15. Quy tắc nghiệp vụ cần trình bày khi bảo vệ

- Grain của `fact_transaction` là một giao dịch nguyên tử
- Sender/receiver được mô hình hóa bằng role-playing dimensions
- Account sử dụng SCD Type 2
- Unknown member giữ fact thay vì silently drop dữ liệu
- Fact dùng source ID để bảo đảm lineage và idempotency
- `is_laundering` là ground truth synthetic
- Amount paid và received phải đi cùng currency tương ứng
- Materialized views là lớp data mart cho Power BI
- Watermark giúp incremental load không quét và chèn lại fact cũ
- Reconciliation chứng minh source và DW không lệch số liệu

## 16. Chạy tự động bằng Terminal – tùy chọn

Nếu muốn chạy nguyên bộ thay vì bấm từng file trong DBeaver:

```bash
cd "/Users/hoangyugi001/Documents/Coder/IBM Transactions"
./scripts/run_week2_postgresql.sh
```

Script tự chạy đúng thứ tự, dừng khi SQL lỗi và ghi log vào `logs/`

DBeaver vẫn là công cụ chính để xem schema, query result và demo project

## 18. Script reset – không chạy bình thường

File sau chỉ dùng khi thật sự muốn xóa toàn bộ DW và chạy lại:

```text
sql/03_dw/99_reset_dw_OPTIONAL.sql
```

File này không xóa `raw.*`, nhưng xóa fact, dimension, audit và validation tuần 2. Không chạy trong quy trình nộp bài

