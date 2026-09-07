# Hướng dẫn chạy đầy đủ Tuần 3 trên macOS

## PostgreSQL + DBeaver + OneDrive/SharePoint + Power BI Service

Tài liệu này là runbook chính thức của Tuần 3. Toàn bộ thao tác được thực hiện
trên macOS và trình duyệt.

## 1. Kết quả cuối cùng cần có

Sau khi hoàn thành Tuần 3:

- PostgreSQL có schema `pbi` và đủ 16 reporting view.
- Reporting view đã vượt qua kiểm tra object, grain, lookup và KPI.
- Snapshot đầy đủ được xuất vào `powerbi/data_snapshot/`.
- Snapshot cloud được tạo trong `powerbi/cloud/data_snapshot_compact/`.
- Workbook `IBM_AML_PowerBI_Cloud_Source.xlsx` được tạo thành công.
- Workbook được lưu đúng vị trí trên OneDrive hoặc SharePoint.
- Semantic model có 18 measure nghiệp vụ.
- Report có một trang hiển thị `IBM AML — Unified Dashboard`, gồm 6 KPI và 7 khu vực phân tích đánh số `01`–`07`.
- KPI trên report khớp với PostgreSQL.

## 2. Kiến trúc Tuần 3

```text
PostgreSQL trên macOS
  source → staging → dw → mart → pbi views
  ↓
Snapshot CSV đã đối soát
  ↓
Snapshot cloud có kiểm soát
  ↓
IBM_AML_PowerBI_Cloud_Source.xlsx
  ↓
OneDrive / SharePoint
  ↓
Power BI semantic model
  ↓
18 DAX measures
  ↓
1 dashboard Power BI Service hợp nhất
```

Power BI Service không đọc trực tiếp PostgreSQL tại `localhost` của Mac.
Workbook cloud là lớp bàn giao ổn định giữa PostgreSQL và semantic model.

## 3. Công cụ cần có trên Mac

- PostgreSQL đang chạy tại `localhost:5432`.
- DBeaver có connection tới database `aml_source`.
- Terminal của macOS.
- Trình duyệt Chrome, Edge hoặc Safari.
- Tài khoản Microsoft có quyền mở workspace Power BI.
- Kết nối OneDrive hoặc SharePoint của cùng tài khoản Microsoft.

Không ghi password, token hoặc cookie đăng nhập vào source code hay file nộp.

## 4. Các file được sử dụng

### SQL

```text
sql/04_powerbi/00_create_powerbi_reporting.sql
sql/04_powerbi/01_validate_powerbi_reporting.sql
sql/04_powerbi/03_refresh_powerbi_reporting.sql
```

### Script

```text
scripts/run_week3_postgresql.sh
scripts/export_powerbi_snapshot.sh
scripts/build_powerbi_cloud_snapshot.py
scripts/build_powerbi_cloud_workbook.mjs
scripts/validate_week3.sh
```

### Đầu ra

```text
powerbi/data_snapshot/
powerbi/cloud/data_snapshot_compact/
outputs/powerbi_cloud_20260723/IBM_AML_PowerBI_Cloud_Source.xlsx
outputs/powerbi_cloud_20260723/POWER_BI_CLOUD_LINKS.txt
powerbi/cloud/mockups_4k/
```

## 5. Cách nhanh nhất: chạy script tự động

Mở Terminal:

```bash
cd "/Users/hoangyugi001/Documents/Coder/IBM Transactions"
chmod +x scripts/run_week3_postgresql.sh
./scripts/run_week3_postgresql.sh
```

Script thực hiện theo thứ tự:

1. Kiểm tra PostgreSQL.
2. Tạo hoặc cập nhật schema `pbi`.
3. Chạy validation reporting layer.
4. Xuất 16 CSV đầy đủ.
5. Tạo snapshot cloud có kiểm soát.
6. Tạo workbook nguồn cho Power BI Service.
7. Chạy kiểm tra đầu ra Tuần 3.

Kết thúc thành công phải có dòng:

```text
Week 3 macOS cloud package completed.
```

Sau đó tiếp tục từ Mục 10 để upload workbook và refresh Power BI Service.

## 6. Chạy thủ công Bước 1 - kiểm tra PostgreSQL

Trong Terminal:

```bash
pg_isready -h localhost -p 5432
```

Kết quả đúng:

```text
localhost:5432 - accepting connections
```

Kiểm tra database:

```bash
psql -X -d aml_source -c "SELECT current_database(), current_user;"
```

Nếu lệnh `psql` không có trong `PATH`, vẫn có thể chạy toàn bộ SQL trong
DBeaver.

## 7. Chạy thủ công Bước 2 - tạo reporting layer trong DBeaver

1. Mở DBeaver.
2. Mở connection PostgreSQL tới `localhost:5432`.
3. Chọn database `aml_source`.
4. Mở SQL Editor.
5. Mở file:

```text
sql/04_powerbi/00_create_powerbi_reporting.sql
```

6. Chạy toàn bộ file.
7. Mở tiếp:

```text
sql/04_powerbi/01_validate_powerbi_reporting.sql
```

8. Chạy toàn bộ file.
9. Refresh cây đối tượng:

```text
Schemas → pbi → Views
```

10. Kiểm tra có đủ 16 view.

Truy vấn kiểm tra nhanh:

```sql
SELECT COUNT(*) AS pbi_view_count
FROM information_schema.views
WHERE table_schema = 'pbi';
```

Kết quả mong đợi:

```text
16
```

Kiểm tra KPI:

```sql
SELECT *
FROM pbi.kpi_overview;
```

Snapshot hiện tại phải có:

- `transaction_count = 31,898,238`
- `laundering_count = 35,230`
- `laundering_rate_percent ≈ 0.110445`
- ngày từ `2022-09-01` đến `2022-09-28`

## 8. Chạy thủ công Bước 3 - xuất snapshot đầy đủ

Trong Terminal:

```bash
cd "/Users/hoangyugi001/Documents/Coder/IBM Transactions"
chmod +x scripts/export_powerbi_snapshot.sh
./scripts/export_powerbi_snapshot.sh
```

Kết quả là 16 file CSV trong:

```text
powerbi/data_snapshot/
```

Kiểm tra số file:

```bash
rg --files powerbi/data_snapshot -g '*.csv' | wc -l
```

Kết quả mong đợi:

```text
16
```

Không sửa thủ công count, rate, amount hoặc khóa trong các file CSV.

## 9. Chạy thủ công Bước 4 - tạo snapshot cloud và workbook

Snapshot đầy đủ có các bảng bank và account khá lớn. Script sau tạo bản cloud
có kiểm soát, giữ toàn bộ KPI, date, currency, format, pattern và ETL; đồng
thời lấy top bank/account theo measure nghiệp vụ để workbook chạy ổn định trên
trình duyệt.

```bash
cd "/Users/hoangyugi001/Documents/Coder/IBM Transactions"
"/Users/hoangyugi001/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3" \
  scripts/build_powerbi_cloud_snapshot.py
```

Sau đó tạo workbook:

```bash
"/Users/hoangyugi001/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node" \
  scripts/build_powerbi_cloud_workbook.mjs
```

Đầu ra:

```text
outputs/powerbi_cloud_20260723/IBM_AML_PowerBI_Cloud_Source.xlsx
```

Workbook phải có 16 Excel table. Không đổi tên sheet, table hoặc cột vì
semantic model đang tham chiếu các tên này.

## 10. Bước 5 - cập nhật workbook trên OneDrive hoặc SharePoint

1. Mở `outputs/powerbi_cloud_20260723/POWER_BI_CLOUD_LINKS.txt`.
2. Mở link `OneDrive source workbook`.
3. Đăng nhập đúng tài khoản Microsoft đã dùng tạo report.
4. Upload đè file:

```text
IBM_AML_PowerBI_Cloud_Source.xlsx
```

5. Giữ nguyên tên file và thư mục.
6. Chờ trạng thái upload hoàn tất.
7. Mở workbook trên Excel Online để chắc chắn file không lỗi.

Không tạo một workbook tên mới cho mỗi lần refresh. Nếu đổi tên hoặc đổi
đường dẫn, semantic model cũ sẽ không tự chuyển nguồn.

## 11. Bước 6 - refresh semantic model trên Power BI Service

1. Mở link `Workspace` trong `POWER_BI_CLOUD_LINKS.txt`.
2. Đăng nhập đúng tài khoản.
3. Tìm semantic model:

```text
IBM AML Transactions Semantic Model
```

4. Mở menu của semantic model.
5. Chọn `Refresh now`.
6. Chờ refresh hoàn tất.
7. Nếu giao diện có phần refresh history, kiểm tra lần mới nhất là
   `Completed`.
8. Mở report:

```text
IBM AML Transactions Dashboard
```

9. Kiểm tra thời điểm cập nhật và KPI.

Tên nút có thể thay đổi nhẹ theo giao diện Power BI Service, nhưng cần thao
tác trên semantic model hiện có, không tạo một model mới ngoài ý muốn.

## 12. Tạo lại report trên cloud khi cần

Chỉ thực hiện mục này khi workspace, semantic model hoặc report đã bị xóa.

1. Tạo hoặc mở workspace `IBM AML Transactions DW`.
2. Upload workbook từ OneDrive/SharePoint.
3. Tạo semantic model từ workbook.
4. Kiểm tra đủ 16 table theo `powerbi/cloud/table_manifest.csv`.
5. Tạo 18 measure theo:

```text
powerbi/cloud/IBM_AML_Cloud_Additional_Measures.dax
```

6. Tạo report mới từ semantic model.
7. Áp dụng theme:

```text
powerbi/cloud/IBM_AML_Cloud_Theme.json
```

8. Dựng visual theo:

```text
powerbi/cloud/visual_build_plan_cloud.csv
```

9. Tạo hoặc mở trang `IBM AML — Unified Dashboard`, đặt canvas dạng Custom theo chiều dọc.
10. Gom KPI và các visual vào cùng trang, sau đó ẩn các trang cũ khỏi Reading view.
11. Lưu report với tên `IBM AML Transactions Dashboard`.

## 13. Một dashboard hợp nhất và bảy khu vực phân tích

Trang hiển thị duy nhất là `IBM AML — Unified Dashboard`. Khi xem, chọn
**View → Fit to width** rồi cuộn dọc; không cần chuyển page.

### Khu vực đầu trang — KPI tổng quan

- KPI: Transactions, Laundering, AML rate, Cross-bank, Cross-currency,
  Self-transfer.
- Câu hỏi: Quy mô toàn kỳ và tỷ lệ AML là bao nhiêu?
- Đối soát với `pbi.kpi_overview`.

### 01 — Transaction Trend

- Area/line chart theo ngày.
- Bar chart theo weekday.
- Matrix ngày × payment format.
- Câu hỏi: Khối lượng giao dịch biến động như thế nào?

### 02 — AML Risk by Format

- AML count và AML rate theo payment format.
- Câu hỏi: Format nào có tỷ lệ và khối lượng AML cao?
- Không kết luận format có 0 nhãn là không có rủi ro ngoài dataset.

### 03 — Bank Activity

- Bank sent, received, total participation và AML participation.
- Câu hỏi: Bank nào có mức hoạt động và AML participation cao?
- Participation không phải số giao dịch distinct.

### 04 — Currency Flow

- Payment currency → receiving currency.
- Câu hỏi: Corridor nào có quy mô và AML đáng chú ý?
- Không cộng amount của nhiều currency khi chưa có tỷ giá chính thức.

### 05 — Laundering Pattern

- Pattern attempt, transaction, sequence và transaction/attempt.
- Câu hỏi: Pattern nào có cường độ hoặc chuỗi dài?
- Không nối trực tiếp pattern summary với daily fact.

### 06 — AML Account Risk

- Account, entity, bank, sent/received AML participation.
- Câu hỏi: Account nào cần ưu tiên review?
- Đây là xếp hạng điều tra, không phải kết luận pháp lý.

### 07 — ETL Data Quality

- Batch status, duration, inserted, rejected.
- Validation source, target, difference và status.
- Câu hỏi: Pipeline có hoàn tất và đối soát thành công không?

Các trang 01–08 trước đây đã được ẩn để Reading view chỉ còn một dashboard.
Không xóa các trang cũ nếu vẫn cần rollback hoặc đối chiếu cấu hình visual.

## 14. Quy tắc semantic model

- Relationship dùng hướng lọc `Single`.
- Không tạo relationship fact-to-fact.
- Không tạo many-to-many nếu chưa có quyết định thiết kế rõ ràng.
- `dim_date` lọc `fact_daily_transaction` qua `date_key`.
- Payment currency và receiving currency là hai role riêng.
- `kpi_overview` và `data_quality_overview` giữ disconnected.
- Ẩn các cột kỹ thuật `*_key` khỏi report view khi không cần hiển thị.
- Không tạo KPI tổng amount trên nhiều currency.

## 15. Đối soát sau refresh

Chạy trong DBeaver:

```sql
SELECT
    transaction_count,
    laundering_count,
    laundering_rate_percent,
    cross_bank_count,
    cross_currency_count,
    self_transfer_count,
    min_transaction_date,
    max_transaction_date
FROM pbi.kpi_overview;
```

Đối chiếu trên Power BI:

| KPI | Giá trị snapshot hiện tại |
|---|---:|
| Transactions | 31,898,238 |
| Laundering | 35,230 |
| AML rate | 0.110445% |
| Cross-bank | 29,092,624 |
| Cross-currency | 485,144 |
| Self-transfer | 2,561,860 |

Chạy kiểm tra tự động:

```bash
cd "/Users/hoangyugi001/Documents/Coder/IBM Transactions"
chmod +x scripts/validate_week3.sh
./scripts/validate_week3.sh
```

Chỉ nghiệm thu khi:

- Có đủ 16 view PostgreSQL.
- Có đủ 16 CSV snapshot.
- Workbook mở được.
- Reading view chỉ hiển thị `IBM AML — Unified Dashboard`.
- Dashboard có đủ 6 KPI và 7 khu vực `01`–`07`.
- KPI khớp PostgreSQL.
- Validation không có trạng thái `FAILED`.

## 16. Refresh sau khi ETL có dữ liệu mới

Thứ tự bắt buộc:

1. Hoàn tất ETL Tuần 2.
2. Trong DBeaver chạy:

```text
sql/04_powerbi/03_refresh_powerbi_reporting.sql
```

3. Chạy `scripts/export_powerbi_snapshot.sh`.
4. Chạy `scripts/build_powerbi_cloud_snapshot.py`.
5. Chạy `scripts/build_powerbi_cloud_workbook.mjs`.
6. Upload đè workbook tại cùng đường dẫn.
7. Refresh semantic model.
8. Mở report và đối soát KPI.

Không export snapshot khi ETL vẫn đang chạy.

## 17. Lỗi thường gặp trên macOS

### PostgreSQL không sẵn sàng

Kiểm tra:

```bash
pg_isready -h localhost -p 5432
```

Nếu lỗi, mở PostgreSQL service trước rồi chạy lại.

### DBeaver không thấy schema `pbi`

- Kiểm tra đang ở database `aml_source`.
- Chạy lại `00_create_powerbi_reporting.sql`.
- Refresh `Schemas`.

### Script báo thiếu `psql`

- Chạy SQL bằng DBeaver.
- Hoặc thêm PostgreSQL `bin` vào `PATH`.

### Workbook không có dữ liệu mới

- Kiểm tra đã chạy export sau ETL.
- Kiểm tra timestamp của CSV.
- Chạy lại script tạo snapshot cloud và workbook.

### Power BI báo `File not found`

- Kiểm tra workbook có đúng tên.
- Kiểm tra không đổi thư mục OneDrive/SharePoint.
- Mở lại link workbook bằng đúng tài khoản.

### Power BI yêu cầu credentials

- Đăng nhập lại bằng `Organizational account`.
- Hoàn tất MFA nếu được yêu cầu.
- Sau đó refresh lại semantic model.

### Visual trống

- Kiểm tra table và cột vẫn đúng tên.
- Kiểm tra datatype của measure.
- Kiểm tra relationship và filter context.
- Đối chiếu với mockup 4K và visual build plan.

### KPI không thay đổi theo slicer

Các overall KPI trong `kpi_overview` cố ý disconnected. Dùng measure động từ
fact nếu KPI cần phản hồi slicer.

### Amount quá lớn hoặc không có ý nghĩa

Kiểm tra visual có đang cộng nhiều currency hay không. Chỉ hiển thị amount khi
đã lọc một currency hoặc có tỷ giá chính thức.

## 18. Checklist trước khi kết thúc Tuần 3

- [ ] PostgreSQL `aml_source` hoạt động.
- [ ] Schema `pbi` có đủ 16 view.
- [ ] Validation reporting layer PASS.
- [ ] Có đủ 16 CSV snapshot đầy đủ.
- [ ] Có đủ 16 CSV snapshot cloud.
- [ ] Workbook cloud mở được.
- [ ] Workbook được upload đúng đường dẫn.
- [ ] Semantic model refresh thành công.
- [ ] Có đủ 18 measure.
- [ ] Reading view chỉ có một trang `IBM AML — Unified Dashboard`.
- [ ] Có đủ 6 KPI và 7 khu vực phân tích `01`–`07`.
- [ ] KPI khớp SQL.
- [ ] ETL/Data Quality không có failed validation.
- [ ] Không có password hoặc token trong file nộp.

## 19. File nên mở khi bảo vệ

- `outputs/powerbi_cloud_20260723/POWER_BI_CLOUD_LINKS.txt`
- `docs/20_HuongDanChayTuan3_macOS_PostgreSQL_PowerBI.md`
- `docs/21_DoiSoat_PowerBI_Tuan3.md`
- `powerbi/cloud/visual_build_plan_cloud.csv`
- Power BI report đã đăng nhập sẵn trên trình duyệt.

Kết luận Tuần 3: PostgreSQL vẫn là nguồn chuẩn; Power BI Service sử dụng
snapshot cloud đã đối soát, phù hợp với quy trình làm việc trực tiếp trên
macOS.
