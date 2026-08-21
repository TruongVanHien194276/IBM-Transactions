# IBM AML HI-Medium – Hồ sơ bảo vệ project

## 1. Mục tiêu

Project xây dựng luồng dữ liệu hoàn chỉnh cho bộ IBM Transactions for Anti Money Laundering – HI-Medium:

`CSV nguồn → PostgreSQL source → staging → data warehouse → data mart → Power BI Service → kiểm thử nghiệm thu`

Môi trường triển khai là macOS: PostgreSQL chạy native, thao tác SQL bằng DBeaver và báo cáo được xây dựng trên Power BI Service.

Nguồn dữ liệu: [IBM Transactions for AML – HI-Medium trên Kaggle](https://www.kaggle.com/datasets/ealtman2019/ibm-transactions-for-anti-money-laundering-aml), dữ liệu synthetic theo CDLA-Sharing-1.0. Bài báo mô tả bộ dữ liệu: <https://arxiv.org/abs/2306.16424>.

## 2. Kết quả đã hoàn thành

- 31.898.238 giao dịch được nạp và đối soát từ raw đến fact.
- 2.087.786 tài khoản được chuẩn hóa.
- 35.230 giao dịch có nhãn laundering.
- 22.743 pattern transactions và 2.756 pattern attempts.
- 29.092.624 giao dịch cross-bank.
- 485.144 giao dịch cross-currency.
- 2.561.860 giao dịch self-transfer.
- 7/7 materialized marts đã populated.
- 16 reporting views dành cho Power BI.
- 1 dashboard hợp nhất, 6 KPI tổng quan, 7 khu vực phân tích và 18 DAX measures.
- 8 trang cũ đã được ẩn để report khi demo chỉ hiển thị một trang duy nhất.
- 22/22 acceptance tests đạt, 0 failed.
- 0 invalid row, 0 reject, 0 unknown lookup và 0 SCD overlap.

## 3. File dùng khi nộp và bảo vệ

- Báo cáo Word: `outputs/final_project/report/IBM_AML_BaoCaoTongKet.docx`
- Báo cáo PDF: `outputs/final_project/report/IBM_AML_BaoCaoTongKet.pdf`
- Slide PowerPoint đã cập nhật: `outputs/final_project/presentation/slide_baove.pptx`
- Slide PDF đã cập nhật: `outputs/final_project/presentation/slide_baove.pdf`
- Hướng dẫn bắt đầu: `outputs/final_project/BAT_DAU_TAI_DAY.txt`
- Kịch bản trình bày: `outputs/final_project/KICH_BAN_BAO_VE_15_PHUT.txt`
- Câu hỏi phản biện: `outputs/final_project/CAU_HOI_PHAN_BIEN.txt`
- Link Power BI: `outputs/final_project/POWER_BI_LINKS.txt`
- Checklist cuối: `FINAL_PROJECT_CHECKLIST.md`

File PowerPoint có 26 slide và đủ speaker notes 26/26. Trong PowerPoint chọn **View → Notes** hoặc **Presenter View** để xem lời trình bày; slide 26 là appendix kỹ thuật.

## 4. Chạy lại toàn bộ project

Mở Terminal:

```bash
cd "/Users/hoangyugi001/Documents/Coder/IBM Transactions"
./scripts/run_week1_postgresql.sh
./scripts/run_week2_postgresql.sh
./scripts/run_week3_postgresql.sh
./scripts/run_week4_postgresql.sh
```

Nếu chỉ cần nghiệm thu trước khi bảo vệ, chạy:

```bash
cd "/Users/hoangyugi001/Documents/Coder/IBM Transactions"
./scripts/run_week4_postgresql.sh
```

Kết quả mong đợi:

```text
test_count   = 22
passed_count = 22
failed_count = 0
status       = PASSED
```

## 5. Kết nối PostgreSQL trong DBeaver

```text
Driver: PostgreSQL
Host: localhost
Port: 5432
Database: aml_source
Username: hoangyugi001
Password: để trống theo cấu hình local hiện tại
```

Kiểm tra nhanh:

```sql
SELECT version();
SELECT * FROM qa.v_week4_latest_run;
SELECT * FROM qa.v_week4_latest_results WHERE status = 'FAILED';
SELECT COUNT(*) FROM dw.fact_transaction;
```

Truy vấn FAILED phải trả về 0 dòng; fact phải có 31.898.238 dòng.

## 6. Trình tự demo đề xuất

1. Mở slide và giới thiệu bài toán, quy mô dữ liệu.
2. Mở DBeaver, chạy `qa.v_week4_latest_run`.
3. Chứng minh raw = fact = 31.898.238.
4. Mở report Power BI Service thật; trang `IBM AML — Unified Dashboard` là trang duy nhất đang hiển thị.
5. Chọn **View → Fit to width**, đối chiếu 6 KPI rồi cuộn lần lượt qua 7 khu vực phân tích `01`–`07`.
6. Slide 18–23 sử dụng screenshot của dashboard hợp nhất; các mockup HTML 4K cũ chỉ còn là tài liệu thiết kế tham khảo trong thư mục `powerbi/cloud/mockups_4k/`.
7. Kết luận, nêu giới hạn và hướng phát triển; speaker notes chứa câu lệnh demo dự phòng.

## 7. Quy tắc nghiệp vụ cần nhớ

- Grain của `dw.fact_transaction` là một giao dịch nguồn.
- Khóa nghiệp vụ tài khoản là `(bank_id, account_number)` sau chuẩn hóa.
- `amount_paid` đi với `payment_currency`; `amount_received` đi với `receiving_currency`.
- Không cộng tiền khác currency nếu chưa có tỷ giá quy đổi.
- `is_laundering` là nhãn ground truth của dữ liệu synthetic, không phải dự đoán của project.
- Self-transfer là hành vi cần phân tích, không phải lỗi dữ liệu mặc định.
- Power BI chỉ đọc schema `pbi`; fact chi tiết dùng cho đối soát, không dùng trực tiếp cho mọi visual.

## 8. Giới hạn đã công bố

- Dữ liệu synthetic và chỉ bao phủ 28 ngày.
- Không có đầy đủ branch, balance, fee hoặc transaction status.
- Không có official FX rate nên không quy đổi tổng giá trị về một đồng tiền.
- Power BI Service dùng snapshot trên OneDrive; chưa phải realtime và không tạo file `.pbix`.
- Project chưa xây dựng mô hình machine learning chấm điểm AML.

Các giới hạn này được nêu rõ trong báo cáo và slide để tránh diễn giải quá phạm vi dữ liệu.
