# Checklist nộp và bảo vệ IBM AML

## File bàn giao

- [x] Báo cáo tổng kết Word mở được.
- [x] Báo cáo tổng kết Word/PDF đã đồng bộ dashboard hợp nhất.
- [x] PowerPoint template đỏ 26 slide.
- [x] Speaker notes có trên 26/26 slide.
- [x] Slide PDF 26 trang.
- [x] Kịch bản trình bày 15 phút.
- [x] Bộ câu hỏi phản biện.
- [x] Link Power BI Service và phương án dự phòng.
- [x] SQL, script, evidence và tài liệu tuần 1–4 còn đầy đủ.

## Database

- [x] PostgreSQL 17.10 native macOS.
- [x] Database `aml_source`.
- [x] Raw/fact = 31.898.238.
- [x] 22/22 acceptance tests PASSED.
- [x] Failed test = 0.
- [x] Reject = 0.
- [x] Unknown lookup = 0.
- [x] SCD overlap = 0.
- [x] 7/7 materialized marts populated.
- [x] 16 Power BI reporting views.

## Trước giờ bảo vệ

- [ ] Chạy `./scripts/run_week4_postgresql.sh`.
- [ ] Mở sẵn DBeaver và ba truy vấn demo.
- [ ] Đăng nhập Power BI bằng tài khoản trường.
- [ ] Mở sẵn `IBM AML — Unified Dashboard`, chọn **View → Fit to width**.
- [ ] Cuộn thử qua đủ 6 KPI và 7 khu vực `01`–`07`.
- [ ] Mở PowerPoint ở Presenter View và kiểm tra Notes.
- [ ] Tắt thông báo macOS.
- [ ] Cắm sạc và kiểm tra màn hình ngoài.
- [ ] Có bản PDF dự phòng khi PowerPoint lỗi.
- [ ] Có ảnh dashboard dự phòng khi mất mạng.
- [ ] Không để lộ password hoặc credential.

## Thông điệp phải nói đúng

- [ ] `is_laundering` là ground-truth label synthetic, không phải dự đoán.
- [ ] Không cộng tiền khác currency nếu chưa có tỷ giá.
- [ ] Power BI Service dùng snapshot, chưa phải realtime.
- [ ] Cloud-only nên không có file PBIX.
- [ ] Nêu rõ giới hạn dữ liệu và hướng phát triển.
