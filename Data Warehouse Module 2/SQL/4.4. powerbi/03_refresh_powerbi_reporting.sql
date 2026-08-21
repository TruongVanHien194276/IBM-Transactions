/*
Chạy sau khi ETL tuần 2 nạp thêm dữ liệu.
Sau khi procedure hoàn tất:
1. Export lại snapshot.
2. Tạo lại workbook cloud.
3. Upload đè workbook trên OneDrive/SharePoint.
4. Refresh semantic model trên Power BI Service.
*/

CALL pbi.refresh_reporting_data();

SELECT *
FROM pbi.data_quality_overview;

SELECT *
FROM pbi.kpi_overview;
