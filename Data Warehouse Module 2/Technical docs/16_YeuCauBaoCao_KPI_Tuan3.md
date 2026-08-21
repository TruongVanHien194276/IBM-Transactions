# Yêu cầu báo cáo và KPI Power BI - Tuần 3

## 1. Mục tiêu

- Trực quan hóa dữ liệu IBM AML HI-Medium đã ETL vào PostgreSQL.
- Không đọc trực tiếp `raw`; nguồn báo cáo là schema `pbi`.
- Cung cấp góc nhìn nghiệp vụ, AML, ngân hàng, currency, pattern và vận hành ETL.
- Mỗi KPI phải có định nghĩa, grain, phép tính, bộ lọc và truy vấn đối soát.

## 2. Đối tượng sử dụng

- Quản lý: xem KPI tổng quan và xu hướng.
- AML analyst: xem payment format, tài khoản và pattern có rủi ro.
- Operations: xem bank/currency flow.
- Data engineer: theo dõi ETL, reject và validation.

## 3. KPI tổng quan

- Total Transactions: `31.898.238`.
- Laundering Transactions: `35.230`.
- AML Rate: `35.230 / 31.898.238 = 0,110445%`.
- Cross-bank Transactions: `29.092.624`.
- Cross-bank Rate: `91,2028%`.
- Cross-currency Transactions: `485.144`.
- Cross-currency Rate: `1,5209%`.
- Self-transfer Transactions: `2.561.860`.
- Self-transfer Rate: `8,0314%`.
- Data Period: `01/09/2022 - 28/09/2022`.

## 4. Quy tắc nghiệp vụ

- Không cộng amount của nhiều currency thành một tổng chung nếu chưa có tỷ giá.
- Amount phải luôn hiển thị kèm payment currency hoặc receiving currency.
- `total_participations` là lượt tham gia ở vai trò gửi/nhận, không phải distinct transaction.
- Một self-transfer có thể đóng góp cả sender và receiver participation.
- `fact_pattern_summary` và `fact_daily_transaction` có grain khác nhau.
- Không nối trực tiếp hai fact.
- KPI trong `kpi_overview` là toàn kỳ và không phản ứng với slicer.
- KPI cần phản ứng với Date/Currency/Payment Format phải tính từ `fact_daily_transaction`.
- `laundering_participations` là lượt tài khoản tham gia, không phải số laundering transaction duy nhất.
- Nhãn AML của dataset là synthetic ground truth, không phải kết luận pháp lý.

## 5. Dashboard hợp nhất

- Một trang hiển thị duy nhất: `IBM AML — Unified Dashboard`.
- Đầu trang: 6 KPI tổng quan.
- Khu vực `01`: Transaction Trend.
- Khu vực `02`: AML theo payment format.
- Khu vực `03`: Bank Activity.
- Khu vực `04`: Currency Flow.
- Khu vực `05`: Laundering Pattern.
- Khu vực `06`: AML Account Risk.
- Khu vực `07`: ETL & Data Quality.

## 6. Tiêu chí nghiệm thu

- Power BI Service lấy reporting snapshot đã đối soát từ workbook OneDrive/SharePoint.
- Workbook chứa 16 reporting tables xuất từ schema `pbi`.
- Semantic model dùng quan hệ `1:*`, single direction.
- Có `_Measures` và explicit measures.
- Có Date table và hierarchy.
- Reading view chỉ hiển thị một dashboard và có đủ 7 khu vực phân tích.
- KPI đối chiếu SQL chính xác.
- Không có many-to-many không chủ đích.
- Không có tổng amount trộn currency.
- Có theme, tiêu đề giải thích visual, Top N và định dạng có điều kiện khi phù hợp.
- Refresh thành công sau khi chạy `CALL pbi.refresh_reporting_data()`.
- Report lưu thành công trên Power BI Service; quy trình cloud-only không yêu cầu file `.pbix`.
