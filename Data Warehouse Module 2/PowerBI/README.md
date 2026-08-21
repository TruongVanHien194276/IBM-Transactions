# IBM AML - Bộ bàn giao Power BI Service Tuần 3

Thư mục này chứa lớp dữ liệu và tài nguyên báo cáo chạy trực tiếp trên macOS
và Power BI Service.

## Luồng chính

```text
PostgreSQL pbi views
→ powerbi/data_snapshot
→ powerbi/cloud/data_snapshot_compact
→ IBM_AML_PowerBI_Cloud_Source.xlsx
→ OneDrive/SharePoint
→ Power BI semantic model
→ 1 dashboard hợp nhất: 6 KPI + 7 khu vực phân tích
```

## Thư mục đang sử dụng

- `cloud/data_snapshot_compact/`: 16 CSV dùng tạo workbook cloud.
- `cloud/table_manifest.csv`: danh sách table và vai trò semantic.
- `cloud/visual_build_plan_cloud.csv`: field, measure và visual gốc; dùng làm catalogue để đối chiếu các khu vực trên dashboard hợp nhất.
- `cloud/IBM_AML_Cloud_Theme.json`: theme của report.
- `cloud/IBM_AML_Cloud_Additional_Measures.dax`: DAX bổ sung.
- `cloud/mockups_4k/`: ảnh tham chiếu độ phân giải cao.
- `data_snapshot/`: snapshot đầy đủ được export từ PostgreSQL.

## Thư mục tham chiếu

- `dax/`, `model/`, `dashboard/` và `powerquery/` lưu thiết kế kỹ thuật ban
  đầu để đối chiếu.
- `mockups/` là bản tham chiếu cũ có độ phân giải thấp hơn.

## Cách chạy

Xem:

```text
docs/20_HuongDanChayTuan3_macOS_PostgreSQL_PowerBI.md
```

Lệnh tự động:

```bash
cd "/Users/hoangyugi001/Documents/Coder/IBM Transactions"
./scripts/run_week3_postgresql.sh
```

Sau khi script hoàn tất, upload đè workbook tại cùng đường dẫn cloud và
refresh semantic model hiện có.

## Dashboard Power BI Service đang sử dụng

- Trang hiển thị duy nhất: `IBM AML — Unified Dashboard`.
- Bố cục: KPI tổng quan ở đầu trang, sau đó là 7 khu vực đánh số từ xu hướng giao dịch đến ETL/Data Quality.
- Chọn **View → Fit to width** và cuộn dọc để xem; không cần chuyển page.
- Các trang cũ được ẩn, không bị xóa.

## Preview thiết kế và ảnh 4K

Các preview và ảnh 4K đã được tạo sẵn trong gói nộp. Bản đóng gói chỉ giữ
các script thực thi pipeline, không kèm script nội bộ sinh mockup.

Khi cần cập nhật dữ liệu snapshot từ PostgreSQL:

```bash
cd "/Users/hoangyugi001/Documents/Coder/IBM Transactions"
./scripts/export_powerbi_snapshot.sh
```

Mở preview:

```bash
open powerbi/cloud/design/IBM_AML_Dashboard_4K_Preview.html
```

Menu `01`–`07` trong preview là liên kết giữa các mockup thiết kế cũ, không
phải menu page của report đang chạy. Nhấn `Command + R` nếu trình duyệt đang giữ phiên bản cũ. Ảnh đầu ra nằm trong
`powerbi/cloud/mockups_4k/`.

Preview HTML và ảnh PNG dùng làm tài liệu thiết kế tham khảo; slide và báo cáo
chính sử dụng screenshot mới từ dashboard Power BI hợp nhất.

PostgreSQL là nguồn chuẩn để đối soát. Không sửa thủ công KPI trong CSV hoặc
workbook.
