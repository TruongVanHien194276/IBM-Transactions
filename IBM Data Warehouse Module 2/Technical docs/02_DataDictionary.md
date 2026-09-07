# Data Dictionary – IBM AML HI-Medium

## 1. File `HI-Medium_Trans.csv`

| Cột nguồn | Kiểu | Bắt buộc | Ý nghĩa nghiệp vụ | Quy tắc |
|---|---|---:|---|---|
| Timestamp | `timestamp without time zone` | Có | Thời điểm giao dịch | Parse format `yyyy/MM/dd HH:mm`; không tự gán timezone |
| From Bank | `text` raw và normalized | Có | Ngân hàng gửi | Chuyển qua `bigint` rồi về `text` để loại padding zero |
| Account (thứ nhất) | `text` | Có | Tài khoản gửi | Uppercase/trim; khóa cùng From Bank |
| To Bank | `text` raw và normalized | Có | Ngân hàng nhận | Chuẩn hóa giống From Bank |
| Account (thứ hai) | `text` | Có | Tài khoản nhận | Uppercase/trim; khóa cùng To Bank |
| Amount Received | `numeric(24,8)` | Có | Số tiền phía nhận | Đi cùng Receiving Currency |
| Receiving Currency | `text` | Có | Currency phía nhận | Không cộng lẫn currency |
| Amount Paid | `numeric(24,8)` | Có | Số tiền phía gửi | Đi cùng Payment Currency |
| Payment Currency | `text` | Có | Currency phía gửi | Không cộng lẫn currency |
| Payment Format | `text` | Có | Phương thức thanh toán | Chuẩn hóa trim; chưa tự gộp category |
| Is Laundering | `boolean` | Có | Ground truth AML | CSV chỉ 0/1; PostgreSQL lưu false/true |

## 2. File `HI-Medium_accounts.csv`

| Cột nguồn | Kiểu | Bắt buộc | Ý nghĩa nghiệp vụ | Quy tắc |
|---|---|---:|---|---|
| Bank Name | `text` | Có | Tên ngân hàng synthetic | Có thể lặp trên nhiều account |
| Bank ID | `text` raw và normalized | Có | Định danh ngân hàng | Chuẩn hóa padding zero khi join |
| Account Number | `text` | Có | Mã tài khoản | Không coi duy nhất nếu thiếu Bank ID |
| Entity ID | `text` | Không | Định danh chủ thể | Dùng để phân tích quan hệ entity-account |
| Entity Name | `text` | Không | Tên chủ thể synthetic | Không phải PII thật |

## 3. File `HI-Medium_Patterns.txt`

| Thành phần | Ý nghĩa | Xử lý |
|---|---|---|
| BEGIN LAUNDERING ATTEMPT | Bắt đầu một attempt | Tăng PatternAttemptID |
| Pattern description | Loại và tham số pattern | Tách PatternType trước dấu `:` |
| Transaction line | Giao dịch thuộc attempt | Parse 11 trường như transaction source |
| END LAUNDERING ATTEMPT | Kết thúc attempt | Đóng block hiện tại |
| Pattern sequence | Thứ tự dòng trong attempt | Sinh tuần tự từ 1 |

## 4. Cột dẫn xuất nguồn

| Cột | Công thức/nguồn | Ý nghĩa |
|---|---|---|
| source_row_id | PostgreSQL identity theo thứ tự `COPY` | Truy vết về dòng CSV |
| load_batch_id | `etl.load_batch.batch_id` | Truy vết lần nạp |
| IsCrossBank | FromBankID khác ToBankID | Giao dịch liên ngân hàng |
| IsCrossCurrency | PaymentCurrency khác ReceivingCurrency | Giao dịch đổi currency |
| IsSelfTransfer | Cùng bank và account | Tự chuyển tiền |
| ImpliedExchangeRate | AmountReceived / AmountPaid | Tỷ giá suy diễn, chỉ khi khác currency và paid > 0 |

## 5. Khóa và quan hệ

- Bank business key: `Normalized BankID`
- Account business key: `(Normalized BankID, AccountNumber)`
- Transaction technical key: `source_transaction_id` identity trong database nguồn
- Pattern attempt key: `PatternAttemptID` sinh từ mỗi BEGIN/END block
- `raw.transactions` không ép foreign key cứng sang `raw.account`; dữ liệu thiếu master được đo và báo cáo thay vì làm thất bại toàn bộ load
