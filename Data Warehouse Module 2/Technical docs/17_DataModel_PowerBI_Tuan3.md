# Data Model Power BI - Tuần 3

## 1. Nguồn dữ liệu

- Nguồn chuẩn: PostgreSQL `aml_source` trên macOS.
- Lớp công bố: 16 view trong schema `pbi`.
- Snapshot đầy đủ: `powerbi/data_snapshot/`.
- Snapshot cloud: `powerbi/cloud/data_snapshot_compact/`.
- Workbook: `IBM_AML_PowerBI_Cloud_Source.xlsx`.
- Lưu trữ: OneDrive/SharePoint.
- Storage mode: Import.
- Semantic model và report được author trực tiếp trên Power BI Service.
- PostgreSQL vẫn là nguồn đối soát; workbook là lớp bàn giao cloud.

## 2. Dimension

- `dim_date`: 28 dòng.
- `dim_payment_currency`: 15 dòng.
- `dim_receiving_currency`: 15 dòng.
- `dim_payment_format`: 7 dòng.
- `dim_bank`: 122.333 dòng.
- `dim_pattern_type`: 8 dòng.

## 3. Fact/summary

- `fact_daily_transaction`: grain Date × Payment Currency × Payment Format; 1.420 dòng.
- `fact_aml_payment_format`: grain Payment Format; 7 dòng.
- `fact_bank_activity`: grain Bank; 122.333 dòng.
- `fact_currency_flow`: grain Payment Currency × Receiving Currency; 223 dòng.
- `fact_pattern_summary`: grain Pattern Type; 8 dòng.
- `fact_aml_account_risk`: grain Account; 41.857 dòng.

## 4. Bảng control

- `kpi_overview`: KPI cố định toàn kỳ; 1 dòng.
- `etl_batch_monitor`: lịch sử batch.
- `etl_validation_result`: chi tiết validation.
- `data_quality_overview`: trạng thái chất lượng mới nhất; 1 dòng.

## 5. Quan hệ

- `dim_date[date_key]` 1 → * `fact_daily_transaction[date_key]`.
- `dim_payment_currency[payment_currency_key]` 1 → * `fact_daily_transaction[payment_currency_key]`.
- `dim_payment_format[payment_format_key]` 1 → * `fact_daily_transaction[payment_format_key]`.
- `dim_payment_format[payment_format_key]` 1 → * `fact_aml_payment_format[payment_format_key]`.
- `dim_bank[bank_key]` 1 → * `fact_bank_activity[bank_key]`.
- `dim_bank[bank_key]` 1 → * `fact_aml_account_risk[bank_key]`.
- `dim_payment_currency[payment_currency_key]` 1 → * `fact_currency_flow[payment_currency_key]`.
- `dim_receiving_currency[receiving_currency_key]` 1 → * `fact_currency_flow[receiving_currency_key]`.
- `dim_pattern_type[pattern_type_key]` 1 → * `fact_pattern_summary[pattern_type_key]`.
- `etl_batch_monitor[dw_batch_id]` 1 → * `etl_validation_result[dw_batch_id]`.

## 6. Cấu hình model

- Tất cả relationship dùng Cross filter direction = Single.
- Không tạo quan hệ cho `kpi_overview` và `data_quality_overview`.
- Dùng `dim_date[full_date]` làm cột ngày chuẩn.
- Sort `month_name` by `month_number`.
- Sort `year_month` by `year_month_sort`.
- Ẩn tất cả cột `*_key` trong Report view.
- Không tạo relationship fact-to-fact.
- Giữ nguyên tên 16 Excel table để refresh semantic model không mất nguồn.
- DAX dùng `VALUE()` khi cột numeric từ Excel được nhận dạng là text.

## 7. Kiểm soát ambiguity

- Currency được tách thành hai role-playing dimensions.
- `dim_payment_currency` lọc payment role.
- `dim_receiving_currency` lọc receiving role.
- KPI overview cố tình disconnected để tránh người dùng hiểu nhầm rằng slicer làm thay đổi KPI toàn kỳ.
