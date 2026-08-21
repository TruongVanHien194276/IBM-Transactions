# IBM AML Data Warehouse Project

Project Data Engineering/Data Warehouse sử dụng bộ **IBM Transactions for Anti Money Laundering (AML) – HI-Medium**


- Bắt đầu: `README_FINAL_PROJECT.txt` hoặc `outputs/final_project/BAT_DAU_TAI_DAY.txt`
- Báo cáo chính: `outputs/final_project/report/IBM_AML_BaoCaoTongKet.docx`
- PowerPoint chính: `outputs/final_project/presentation/slide_baove.pptx`
- Zip nộp cuối: `outputs/IBM_AML_Final_Project_Submission_20260802.zip`.

## Trạng thái giai đoạn 1

- Hoàn thành trên PostgreSQL 17.10 native macOS.
- Quản trị và chạy SQL bằng DBeaver
- Database nguồn: `aml_source`
- Full load đạt 31.898.238 giao dịch, 2.087.786 tài khoản và 22.743 pattern transactions
- Rejected rows: 0

## Phạm vi giai đoạn 1 đã hoàn thành

- Liên kết và tổ chức thư mục project
- Tải đúng 3 file HI-Medium từ Kaggle và khóa bằng SHA-256
- Parse laundering patterns thành bảng CSV có cấu trúc
- Profile toàn bộ nguồn và lập báo cáo chất lượng dữ liệu
- Xây dựng source database PostgreSQL theo mô hình landing → typed source
- Thực hiện ETL chuẩn hóa Bank ID, account key, timestamp, amount và AML label
- Tạo batch audit, rejected-row handling, index và source views
- Chạy reconciliation giữa file, landing và typed source
- Hoàn thiện tài liệu nghiệp vụ, data dictionary, ERD và hướng dẫn DBeaver

## Cấu trúc thư mục

```text
IBM Transactions/
├── data/
│   ├── raw/                 # File Kaggle gốc, không chỉnh sửa
│   ├── processed/           # Pattern CSV đã parse
│   ├── profile/             # DuckDB profiling và thống kê
│   └── reject/              # Vùng xuất reject nếu phát sinh
├── docs/                    # Tài liệu và báo cáo giai đoạn 1
├── sql/
│   ├── 01_source/           # PostgreSQL source pipeline theo thứ tự 00–07
│   └── 02_profiling/        # Truy vấn nghiệp vụ mẫu
├── scripts/                 # Download, parse, profile và source load
├── logs/
└── WEEK1_CHECKLIST.md
```

## Kết nối DBeaver

```text
Driver: PostgreSQL
Host: localhost
Port: 5432
Database: aml_source
Username: hoangyugi001
Password: để trống theo cấu hình local hiện tại
```

Local PostgreSQL hiện dùng `trust` cho localhost

## Chạy SQL trong DBeaver

- Nếu `aml_source` chưa tồn tại: kết nối database `postgres`, bật Auto-commit và chạy `sql/01_source/00_create_database.sql`
- Chuyển connection sang database `aml_source`
- Chạy lần lượt các file `01` đến `07` bằng **Execute SQL Script**
- `02_load_landing.sql` dùng PostgreSQL `COPY` và đường dẫn tuyệt đối tới CSV trên máy này
- Hướng dẫn chi tiết: `docs/06_HuongDanChayTuan1.md`
- Chạy lại tự động bằng terminal (tùy chọn):

```bash
cd "/Users/hoangyugi001/Documents/Coder/IBM Transactions"
./scripts/run_week1_postgresql.sh
```

## Quy ước nghiệp vụ

- 1 dòng `HI-Medium_Trans.csv` là 1 giao dịch giữa tài khoản gửi và tài khoản nhận
- Khóa nghiệp vụ tài khoản là `(bank_id, account_number)` sau chuẩn hóa
- `amount_paid` đi với `payment_currency`; `amount_received` đi với `receiving_currency`
- Không cộng tiền khác currency và không tự xem chênh lệch paid/received là phí
- `is_laundering` là nhãn ground truth synthetic, không phải cảnh báo do project phát hiện
- Self-transfer là hành vi cần đo lường, không phải lỗi cấu trúc phải loại

## Phạm vi công nghệ

- Giai đoạn 1: PostgreSQL source database và DBeaver
- Giai đoạn 2: PostgreSQL Data Warehouse, ETL bằng SQL/procedure, SCD Type 2,
  reconciliation và materialized data mart; không dùng SSIS.
- Giai đoạn tiếp theo: Power BI kết nối schema `mart`

## Giai đoạn 2 – Data Warehouse

- Kiến trúc trong database `aml_source`: `raw → stg → dw → mart`
- SQL chạy theo thứ tự trong `sql/03_dw/` từ file `00` đến `07`
- Hướng dẫn chi tiết: `docs/13_HuongDanChayTuan2.md`
- Hoàn thành FULL batch 1: `31.898.238` transaction, `22.743` pattern,
  `0` reject, validation `PASSED`
- Hoàn thành INCREMENTAL no-change batch 2: insert `0` dòng,
  validation `PASSED`
- Bảy materialized views trong schema `mart` đã populated
- Chạy tự động tùy chọn:

```bash
cd "/Users/hoangyugi001/Documents/Coder/IBM Transactions"
./scripts/run_week2_postgresql.sh
```

## Nguồn

- Kaggle dataset: `ealtman2019/ibm-transactions-for-anti-money-laundering-aml`
- License: Community Data License Agreement – Sharing 1.0

## Giai đoạn 3 - Power BI Service Cloud

- Dùng Power BI Service trực tiếp trong trình duyệt trên macOS
- Workspace: `IBM AML Transactions DW`
- Semantic model: `IBM AML Transactions Semantic Model`
- Report: `IBM AML Transactions Dashboard`
- 18 DAX measures và một dashboard hợp nhất gồm 6 KPI cùng 7 khu vực phân tích đánh số `01`–`07`
- Tám trang cũ đã được ẩn trong Power BI Service để tránh nhầm khi demo; chúng không bị xóa và có thể bật lại khi cần đối chiếu
- Nguồn cloud là workbook OneDrive gồm 16 reporting tables
- Tài liệu: `docs/20_HuongDanChayTuan3_macOS_PostgreSQL_PowerBI.pdf`

### Mở dashboard Power BI hợp nhất trên macOS

1. Mở link trong `outputs/final_project/POWER_BI_LINKS.txt`
2. Chọn report `IBM AML Transactions Dashboard`
3. Report mở thẳng trang `IBM AML — Unified Dashboard`
4. Chọn **View → Fit to width**, sau đó cuộn dọc từ KPI tổng quan đến khu vực `07 — ETL & Data Quality`
5. Không cần mở panel Pages hoặc chuyển trang khi demo; toàn bộ nội dung nằm trên một canvas duy nhất

### Preview thiết kế và ảnh 4K trên macOS

Dashboard preview là bản HTML đọc dữ liệu thật từ reporting snapshot. Đây là tài liệu thiết kế tham khảo theo bảy góc nhìn cũ và dùng để tạo ảnh 4K; không phải cấu trúc trang của report Power BI Service đang chạy. Report thật hiện chỉ có một trang hiển thị và đã gom các góc nhìn vào cùng một canvas cuộn dọc

Chạy lần lượt:

```bash
cd "/Users/hoangyugi001/Documents/Coder/IBM Transactions"

./scripts/export_powerbi_snapshot.sh

python3 scripts/build_powerbi_cloud_design.py

"/Users/hoangyugi001/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node" \
scripts/render_powerbi_cloud_mockups.mjs
```

Mở bản preview:

```bash
open powerbi/cloud/design/IBM_AML_Dashboard_4K_Preview.html
```

Trong preview, menu `01`–`07` chỉ chuyển giữa các mockup thiết kế. Nếu file
đang mở từ trước khi tạo lại, nhấn `Command + R` để tải phiên bản mới

Mở thư mục chứa ảnh PNG:

```bash
open powerbi/cloud/mockups_4k
```

Các file chính:

- `01_Executive_Overview_4K.png`
- `02_Transaction_Trend_4K.png`
- `03_AML_Risk_4K.png`
- `04_Bank_Activity_4K.png`
- `05_Currency_Flow_4K.png`
- `06_Laundering_Pattern_4K.png`
- `07_ETL_Data_Quality_4K.png`

## Giai đoạn 4 - Kiểm thử và nghiệm thu

- Tạo schema `qa` lưu lịch sử acceptance test
- Chạy thực tế 22 kiểm thử: `22 PASSED`, `0 FAILED`
- Đối soát chính xác `31.898.238` giao dịch từ raw đến fact và reporting
- Kiểm tra SCD Type 2, Unknown keys, invalid amount, reject và idempotency
- Đánh giá hiệu năng data mart và partial AML index
- Hoàn thiện báo cáo Word/PDF, PowerPoint, README và gói nộp cuối kỳ

Chạy giai đoạn 4:

```bash
cd "/Users/hoangyugi001/Documents/Coder/IBM Transactions"
./scripts/run_week4_postgresql.sh
```

Hướng dẫn nhanh: `README_WEEK4.md`

Gói nộp toàn project đã kiểm tra:

`outputs/IBM_AML_Final_Project_Submission_20260802.zip`
