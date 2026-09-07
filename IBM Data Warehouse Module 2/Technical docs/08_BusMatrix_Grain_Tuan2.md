# Bus Matrix và Grain – IBM AML Data Warehouse

## 1. Grain

- `dw.fact_transaction`: một dòng cho một `raw.transactions.source_transaction_id`.
- `dw.fact_pattern_transaction`: một dòng cho một `raw.laundering_pattern_transaction.pattern_transaction_id`, tức một transaction tại một sequence trong một laundering attempt.
- Không aggregate dữ liệu trước khi nạp fact nguyên tử.
- Các materialized view trong `mart` mới là lớp tổng hợp cho báo cáo.

## 2. Bus Matrix

| Business process | Date | Time | From Bank | To Bank | From Account | To Account | From Entity | To Entity | Paid Currency | Received Currency | Payment Format | Pattern Type |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Transaction | X | X | X | X | X | X | X | X | X | X | X |  |
| Laundering Pattern Transaction | X | X | X | X | X | X | qua account | qua account | X | X | X | X |

## 3. Role-playing dimensions

- `dim_bank` được dùng hai vai trò: From Bank và To Bank.
- `dim_account` được dùng hai vai trò: From Account và To Account.
- `dim_entity` được đưa trực tiếp vào `fact_transaction` qua `from_entity_key` và `to_entity_key` để phân tích nhanh.
- `dim_currency` được dùng hai vai trò: Payment Currency và Receiving Currency.

## 4. Slowly Changing Dimension

| Dimension | Loại | Business key | Lý do |
|---|---|---|---|
| `dim_bank` | Type 1 | `bank_id` | Sửa tên bank hiện tại, không cần lịch sử trong dataset snapshot |
| `dim_entity` | Type 1 | `entity_id` | Chuẩn hóa tên entity hiện tại |
| `dim_account` | Type 2 | `(bank_id, account_number)` | Theo dõi account đổi entity/bank relationship qua thời gian |
| `dim_currency` | Type 1/static | `currency_name` | Reference data |
| `dim_payment_format` | Type 1/static | `payment_format` | Reference data |
| `dim_pattern_type` | Type 1/static | `pattern_type` | Reference data |

## 5. Unknown member

- Mọi dimension có Unknown key bằng `-1`.
- ETL không loại bỏ transaction khi lookup dimension thất bại.
- Transaction vẫn được giữ với key `-1` và được ghi vào `etl.dw_rejected_row`.
- Với dataset hiện tại, số fact dùng Unknown key phải bằng `0`.

## 6. Degenerate dimensions và lineage

- `transaction_key` bằng `source_transaction_id` để giữ lineage và đảm bảo idempotent.
- `pattern_attempt_id` và `pattern_sequence` được giữ trực tiếp trong pattern fact.
- `source_load_batch_id` truy ngược về batch tuần 1.
- `dw_batch_id` truy ngược về batch ETL tuần 2.

