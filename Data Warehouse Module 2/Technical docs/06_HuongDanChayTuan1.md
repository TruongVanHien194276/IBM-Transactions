# Hướng dẫn chạy đầy đủ tuần 1 bằng PostgreSQL và DBeaver trên macOS

## 1. Mục tiêu 

- PostgreSQL database `aml_source`
- 3 schemas: `etl`, `raw`, `src`
- 2.087.786 account rows trong `raw.account`
- 31.898.238 transaction rows trong `raw.transactions`
- 22.743 pattern transaction rows trong `raw.laundering_pattern_transaction`
- Batch mới nhất có trạng thái `COMPLETED`
- `raw.rejected_row` bằng 0 với bộ dữ liệu hiện tại
- Các index và source views phục vụ thiết kế Data Warehouse ở giai đoạn sau
- Tài liệu profiling, data dictionary, source-to-target và mô tả nghiệp vụ


## 2. Thông tin môi trường 

```text
PostgreSQL: 17.10 Homebrew
DBeaver: /Applications/DBeaver.app
Host: localhost
Port: 5432
Database nguồn: aml_source
Username: hoangyugi001
Password: 
Project folder: /Users/hoangyugi001/Documents/Coder/IBM Transactions
```


## 3. Bước 1 – Kiểm tra PostgreSQL đang chạy

Mở Terminal và chạy:

```bash
brew services list | grep postgresql
```

Kết quả phải có `postgresql@17 started`.

Nếu chưa chạy:

```bash
brew services start postgresql@17
```

## 4. Bước 2 – Mở đúng project và xác minh nguồn

Trong Terminal:

```bash
cd "/Users/hoangyugi001/Documents/Coder/IBM Transactions"
```

Xác minh 3 file gốc:

```bash
./scripts/verify_source_files.sh
```

Kết quả: 3 file đều có trạng thái `OK` trong `docs/source_manifest.csv`.

Nếu file còn thiếu, chạy:

```bash
./scripts/download_hi_medium.sh
```

Tạo lại file pattern dạng bảng:

```bash
./scripts/parse_patterns.py
```

Kết quả:

```text
Parsed 2,756 attempts and 22,743 transactions
data/processed/HI-Medium_PatternTransactions.csv
```

Không sửa thủ công các file trong `data/raw`

## 5. Bước 3 – Tạo connection PostgreSQL trong DBeaver

- Mở DBeaver
- Chọn **Database → New Database Connection**
- Chọn **PostgreSQL** rồi chọn **Next**
- Nhập:

```text
Host: localhost
Port: 5432
Database: postgres
Username: hoangyugi001
Password: để trống
```

- Chọn **Test Connection**
- Nếu DBeaver yêu cầu tải JDBC driver, chọn **Download**.
- Khi test thành công, chọn **Finish**

Connection `postgres` chỉ dùng để tạo database project

## 6. Bước 4 – Tạo database `aml_source`

Trong DBeaver:

- Chọn connection `postgres`
- Chọn **SQL Editor → New SQL Script**
- Mở file `sql/01_source/00_create_database.sql`
- Bật **Auto-commit**
- Chọn **Execute SQL Script** trên thanh công cụ

Kết quả:

```text
CREATE DATABASE
```

Nếu DBeaver báo database đã tồn tại, không chạy lại bước này

Kiểm tra bằng SQL:

```sql
SELECT datname
FROM pg_database
WHERE datname = 'aml_source';
```

Phải trả về đúng một dòng `aml_source`

## 7. Bước 5 – Đổi connection sang `aml_source`

- Right-click connection PostgreSQL → **Edit Connection**
- Đổi trường **Database** từ `postgres` thành `aml_source`
- Chọn **Test Connection** rồi **OK/Finish**
- Mở SQL Editor mới
- Kiểm tra active connection phía trên editor là `aml_source`

Chạy:

```sql
SELECT current_database(), current_user;
```

Kết quả phải là:

```text
aml_source | hoangyugi001
```

Không chạy các file `01`–`07` nếu `current_database()` không phải `aml_source`.

## 8. Bước 6 – Tạo source schema

Mở và chạy toàn bộ file:

```text
sql/01_source/01_create_source_schema.sql
```

File tạo:

- `etl.load_batch`
- `raw.account_landing`
- `raw.transaction_landing`
- `raw.pattern_transaction_landing`
- `raw.account`.
- `raw.transactions`.
- `raw.laundering_pattern_transaction`
- `raw.rejected_row`.
- Schema `src` cho business views

Trong Database Navigator, chọn **Refresh**. Phải thấy các schemas `etl`, `raw`, `src`

## 9. Bước 7 – Nạp CSV vào landing

Mở và chạy toàn bộ file:

```text
sql/01_source/02_load_landing.sql
```

Script sử dụng PostgreSQL `COPY`, không dùng DBeaver Import Data. Nó thực hiện:

- Đánh dấu batch cũ còn `STARTED` thành `FAILED`
- Xóa dữ liệu của lần full-load trước
- Tạo batch mới
- Nạp account CSV
- Nạp transaction CSV
- Nạp pattern transaction CSV
- Ghi số dòng landing vào `etl.load_batch`

Đường dẫn trong script phải đúng:

```text
/Users/hoangyugi001/Documents/Coder/IBM Transactions/data/raw/HI-Medium_accounts.csv
/Users/hoangyugi001/Documents/Coder/IBM Transactions/data/raw/HI-Medium_Trans.csv
/Users/hoangyugi001/Documents/Coder/IBM Transactions/data/processed/HI-Medium_PatternTransactions.csv
```

Kết quả:

```text
Account landing:              2.087.786
Transaction landing:         31.898.238
Pattern transaction landing:     22.743
Batch status: STARTED
```


## 10. Bước 8 – Khóa số dòng landing

Mở và chạy:

```text
sql/01_source/03_validate_landing.sql
```

Script sẽ chủ động báo lỗi và dừng nếu số dòng khác kỳ vọng

Kết quả:

```text
account_landing             |  2.087.786
transaction_landing         | 31.898.238
pattern_transaction_landing |     22.743
```

Nếu số dòng sai, không chạy bước transform. Chạy lại `verify_source_files.sh`, sau đó chạy lại `02_load_landing.sql`

## 11. Bước 9 – Transform landing sang typed source

Mở và chạy:

```text
sql/01_source/04_transform_landing_to_source.sql
```

Nghiệp vụ được xử lý:

- Trim khoảng trắng
- Uppercase account number và entity ID
- Giữ Bank ID gốc để audit
- Bỏ zero-padding Bank ID bằng cách chuyển qua `bigint` rồi về `text`
- Parse timestamp theo `YYYY/MM/DD HH24:MI`
- Parse amount thành `numeric(24,8)`
- Chuyển AML label `0/1` thành `false/true`
- Đưa dòng sai cấu trúc vào `raw.rejected_row` cùng error code và raw payload
- Ghi `source_row_id` và `load_batch_id` để truy vết

Kết quả:

```text
account_loaded_rows:       2.087.786
transaction_loaded_rows:  31.898.238
pattern_loaded_rows:          22.743
rejected_rows:                      0
status: COMPLETED
```

## 12. Bước 10 – Tạo index và source views

Mở và chạy:

```text
sql/01_source/05_create_indexes_and_views.sql
```

Script tạo:

- Unique business-key index `(bank_id, account_number)`
- Partial index cho account có entity
- BRIN index theo `transaction_timestamp` cho bảng 31,9 triệu dòng
- Partial AML index chỉ chứa giao dịch laundering
- Index cho pattern attempt và sequence
- `src.vw_bank`
- `src.vw_transaction_business`
- Thống kê `ANALYZE` cho query planner

Chờ tất cả câu lệnh `CREATE INDEX`, `CREATE VIEW`, `ANALYZE` hoàn tất

## 13. Bước 11 – Chạy reconciliation và kiểm tra nghiệp vụ

Mở và chạy:

```text
sql/01_source/06_validate_source.sql
```

Kết quả:

```text
Accounts:                    2.087.786
Transactions:              31.898.238
Pattern transactions:          22.743
Rejected rows:                       0
Min timestamp:        2022-09-01 00:00
Max timestamp:        2022-09-28 15:58
Laundering:                  35.230
Laundering rate:           0,110445%
Active accounts:          2.077.023
Missing account master:           0
Non-positive paid:                 0
Non-positive received:             0
Same-currency mismatch:            0
Cross-bank transactions:  29.092.624
Cross-currency transactions: 485.144
Self-transfers:            2.561.860
```


## 14. Bước 12 – Dọn landing sau khi validation đạt

Chỉ sau khi bước 11 đạt, mở và chạy:

```text
sql/01_source/07_cleanup_landing.sql
```

Mục đích:

- Giải phóng bản sao dữ liệu text trong landing
- Giữ lại typed source, batch audit và rejected rows
- Chạy `VACUUM (ANALYZE)` để cập nhật thống kê PostgreSQL

Kiểm tra landing đã rỗng:

```sql
SELECT
    (SELECT count(*) FROM raw.account_landing) AS account_landing,
    (SELECT count(*) FROM raw.transaction_landing) AS transaction_landing,
    (SELECT count(*) FROM raw.pattern_transaction_landing) AS pattern_landing;
```

Kết quả phải là `0 | 0 | 0`

## 15. Bước 13 – Kiểm tra cuối cùng

Chạy trong DBeaver:

```sql
SELECT
    current_database() AS database_name,
    current_setting('server_version') AS postgresql_version,
    (SELECT count(*) FROM raw.account) AS account_rows,
    (SELECT count(*) FROM raw.transactions) AS transaction_rows,
    (SELECT count(*) FROM raw.laundering_pattern_transaction) AS pattern_rows,
    (SELECT count(*) FROM raw.rejected_row) AS rejected_rows;
```

Kết quả:

```text
aml_source | 17.10 | 2087786 | 31898238 | 22743 | 0
```

Kiểm tra batch:

```sql
SELECT *
FROM etl.load_batch
ORDER BY batch_id DESC
LIMIT 1;
```

Batch mới nhất phải có `status = 'COMPLETED'` và các số dòng phải khớp

## 16. Chạy profiling và tạo lại tài liệu tuần 1

Chỉ chạy lại khi dữ liệu hoặc báo cáo thay đổi:

```bash
cd "/Users/hoangyugi001/Documents/Coder/IBM Transactions"
.profile-venv/bin/python scripts/profile_source.py
```

Đầu ra:

```text
docs/03_BaoCaoKhaoSatNguon.md
data/profile/source_profile.json
data/profile/*.csv
```

Tạo lại báo cáo Word:

```bash
"/Users/hoangyugi001/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3" \
  scripts/build_week1_docx.py
```

## 17. Cách chạy nhanh bằng Terminal – tùy chọn

Nếu không muốn chạy từng file trong DBeaver, có thể chạy cùng pipeline bằng:

```bash
cd "/Users/hoangyugi001/Documents/Coder/IBM Transactions"
./scripts/run_week1_postgresql.sh
```

Kết quả tạo ra giống chuỗi SQL `01`–`07`. Tuy nhiên, khi demo trên lớp nên mở DBeaver và giải thích từng bước theo hướng dẫn phía trên
