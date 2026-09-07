# Power Query M - tài liệu tham chiếu

Các file `.m` trong thư mục này mô tả cách đọc 16 view của schema `pbi` và
được giữ để tham khảo logic kiểu dữ liệu, tên cột và grain.

Quy trình Tuần 3 đang dùng nguồn cloud:

```text
PostgreSQL pbi views
→ CSV snapshot
→ IBM_AML_PowerBI_Cloud_Source.xlsx
→ OneDrive/SharePoint
→ Power BI Service
```

Vì vậy, không cần dán thủ công từng file `.m` khi refresh report hiện có.

Chỉ dùng các file `.m` khi cần kiểm tra:

- Tên query tương ứng với view nào.
- Kiểu dữ liệu mong đợi.
- Cột kỹ thuật nào phải giữ.
- Grain của từng bảng.

Credential không nằm trong M code. Quy trình chạy chính nằm tại:

```text
docs/20_HuongDanChayTuan3_macOS_PostgreSQL_PowerBI.md
```
