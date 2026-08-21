# Yêu cầu báo cáo và KPI – Data Warehouse IBM AML

## 1. Mục tiêu phân tích

- Theo dõi quy mô và xu hướng giao dịch theo thời gian
- Đo tỷ lệ giao dịch có nhãn `is_laundering` theo các chiều nghiệp vụ
- Phân tích luồng tiền theo từng currency mà không cộng lẫn đơn vị
- Xác định ngân hàng, tài khoản và entity tham gia nhiều giao dịch có nhãn AML
- Phân tích cấu trúc các laundering attempt trong file pattern
- Chuẩn bị data mart có grain rõ ràng để Power BI không phải xử lý trực tiếp bảng nguồn

## 2. KPI bắt buộc

| KPI | Công thức | Grain/điều kiện |
|---|---|---|
| Transaction Count | `count(*)` | Không phụ thuộc currency |
| Laundering Count | `count(*) filter (where is_laundering)` | Nhãn ground truth synthetic |
| Laundering Rate | `100 * laundering_count / transaction_count` | Tính trên cùng tập lọc |
| Total Amount Paid | `sum(amount_paid)` | Bắt buộc group theo payment currency |
| Total Amount Received | `sum(amount_received)` | Bắt buộc group theo receiving currency |
| Cross-bank Count | `count(*) where from_bank != to_bank` | Không xem là lỗi |
| Cross-currency Count | `count(*) where payment_currency != receiving_currency` | Không so sánh amount trực tiếp |
| Self-transfer Count | Cùng bank và account ở hai đầu | Hành vi nghiệp vụ, không loại bỏ |
| Active Bank Count | Số bank tham gia giao dịch | Đếm distinct theo role gửi/nhận |
| Active Account Count | Số account tham gia giao dịch | Khóa `(bank_id, account_number)` |
| Pattern Attempt Count | `count(distinct pattern_attempt_id)` | Group theo pattern type |
| Pattern Transaction Count | `count(*)` | Grain pattern transaction |

## 3. Câu hỏi báo cáo

- Giao dịch và tỷ lệ laundering thay đổi thế nào theo ngày?
- Payment format nào có tỷ lệ laundering cao nhất?
- Ngân hàng nào có nhiều lượt gửi/nhận và nhiều AML participation nhất?
- Currency pair nào có nhiều giao dịch nhất?
- Dòng tiền gửi và nhận theo từng currency là bao nhiêu?
- Bao nhiêu giao dịch là cross-bank, cross-currency hoặc self-transfer?
- Account/entity nào xuất hiện nhiều lần trong giao dịch laundering?
- Pattern type nào có nhiều attempt và nhiều transaction nhất?
- Độ dài lớn nhất của sequence theo mỗi pattern type là bao nhiêu?

## 4. Quy tắc trình bày

- Không gọi `is_laundering` là kết quả dự đoán; đây là ground truth của dữ liệu synthetic
- Không cộng `amount_paid` của nhiều payment currency
- Không cộng `amount_received` của nhiều receiving currency
- Không coi chênh lệch paid/received ở cross-currency là phí giao dịch
- Phải ghi rõ bộ lọc thời gian, currency và payment format trên báo cáo
- Laundering rate phải hiển thị cả tử số và mẫu số để tránh diễn giải sai

## 5. Data mart phục vụ báo cáo

| Data mart | Grain | Mục đích |
|---|---|---|
| `mart.mv_kpi_overview` | Một dòng toàn bộ dataset | KPI cards |
| `mart.mv_daily_transaction` | Ngày × paid currency × payment format | Trend và amount |
| `mart.mv_aml_by_payment_format` | Payment format | So sánh AML rate |
| `mart.mv_bank_activity` | Bank | Xếp hạng hoạt động |
| `mart.mv_currency_flow` | Paid currency × received currency | Luồng currency |
| `mart.mv_pattern_summary` | Pattern type | Phân tích attempt |
| `mart.mv_aml_account_risk` | Account | AML participation |

