# Data Dictionary – PostgreSQL Data Warehouse

## 1. Audit và staging

| Object | Grain/mục đích | Khóa chính |
|---|---|---|
| `etl.dw_batch` | Một lần chạy FULL/INCREMENTAL | `dw_batch_id` |
| `etl.dw_rejected_row` | Một source row lỗi lookup trong một batch | `dw_rejected_row_id` |
| `etl.dw_validation_result` | Một validation check của một batch | `validation_result_id` |
| `stg.account_snapshot` | Snapshot account hiện tại phục vụ SCD2 | `(bank_id, account_number)` |
| `stg.v_transaction_enriched` | View dẫn xuất date/time và các flag | `source_transaction_id` |
| `stg.v_pattern_enriched` | View dẫn xuất date/time cho pattern | `pattern_transaction_id` |

## 2. Dimension

### `dw.dim_date`

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `date_key` | integer | `YYYYMMDD`, Unknown = -1 |
| `full_date` | date | Ngày lịch |
| `day_of_month` | smallint | Ngày trong tháng |
| `day_of_week` | smallint | ISO 1=Monday, 7=Sunday |
| `week_of_year` | smallint | Tuần trong năm |
| `month_number` | smallint | Tháng |
| `quarter_number` | smallint | Quý |
| `year_number` | smallint | Năm |
| `is_weekend` | boolean | Thứ bảy/chủ nhật |

### `dw.dim_account`

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `account_key` | bigint | Surrogate key, Unknown = -1 |
| `bank_key` | bigint | Khóa sang bank dimension |
| `entity_key` | bigint | Khóa sang entity dimension |
| `bank_id` | text | Thành phần business key |
| `account_number` | text | Thành phần business key |
| `source_hash` | char(32) | Phát hiện thay đổi thuộc tính |
| `effective_from` | timestamptz | Bắt đầu hiệu lực version |
| `effective_to` | timestamptz | Kết thúc hiệu lực version |
| `is_current` | boolean | Version hiện hành |

### Các dimension khác

| Dimension | Surrogate key | Business key |
|---|---|---|
| `dw.dim_time` | `time_key` dạng HHMM | `time_value` |
| `dw.dim_currency` | `currency_key` | `currency_name` |
| `dw.dim_payment_format` | `payment_format_key` | `payment_format` |
| `dw.dim_bank` | `bank_key` | `bank_id` |
| `dw.dim_entity` | `entity_key` | `entity_id` |
| `dw.dim_pattern_type` | `pattern_type_key` | `pattern_type` |

## 3. `dw.fact_transaction`

| Nhóm | Cột | Ý nghĩa/quy tắc |
|---|---|---|
| Lineage | `transaction_key` | Bằng source transaction ID |
| Lineage | `source_load_batch_id` | Batch source tuần 1 |
| Lineage | `dw_batch_id` | Batch DW tuần 2 |
| Time | `date_key`, `time_key` | Lookup từ timestamp |
| Sender | `from_bank_key`, `from_account_key`, `from_entity_key` | Vai trò gửi |
| Receiver | `to_bank_key`, `to_account_key`, `to_entity_key` | Vai trò nhận |
| Currency | `payment_currency_key` | Đi cùng `amount_paid` |
| Currency | `receiving_currency_key` | Đi cùng `amount_received` |
| Method | `payment_format_key` | Phương thức thanh toán |
| Measure | `amount_paid` | numeric(24,8), lớn hơn 0 |
| Measure | `amount_received` | numeric(24,8), lớn hơn 0 |
| Measure | `implied_exchange_rate` | Received/Paid khi cross-currency |
| Flag | `is_laundering` | Ground truth synthetic |
| Flag | `is_cross_bank` | From Bank khác To Bank |
| Flag | `is_cross_currency` | Payment currency khác receiving currency |
| Flag | `is_self_transfer` | Cùng bank và account |

## 4. `dw.fact_pattern_transaction`

| Cột | Ý nghĩa |
|---|---|
| `pattern_transaction_key` | Technical key từ source pattern row |
| `pattern_attempt_id` | Một block BEGIN/END laundering attempt |
| `pattern_type_key` | Loại pattern |
| `pattern_sequence` | Thứ tự transaction trong attempt |
| `pattern_description` | Mô tả và tham số pattern gốc |
| Các dimension role | Date/time, sender/receiver, currency, payment format |
| Các measure | Amount paid/received |

## 5. Quy tắc integrity

- Fact lớn dùng logical foreign key do ETL kiểm soát để tăng tốc bulk load.
- `etl.validate_dw()` bắt buộc kiểm tra Unknown lookup bằng 0.
- Khóa source trên fact là unique nên chạy lại không tạo duplicate.
- Tổng amount chỉ được đối soát theo từng currency.

