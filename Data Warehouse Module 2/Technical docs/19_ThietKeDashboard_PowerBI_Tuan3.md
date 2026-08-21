# Thiết kế Dashboard Power BI - Tuần 3

## 1. Visual system

- Canvas Power BI Service: Custom `1280 × 2600`, bố cục cuộn dọc.
- Background: `#F8FAFC`.
- Sidebar: `#0F172A`.
- Primary: `#2563EB`.
- AML/risk: `#DC2626`.
- Currency: `#7C3AED`.
- Data quality passed: `#16A34A`.
- Warning: `#F59E0B`.
- Font: Segoe UI.
- Theme: `powerbi/theme/IBM_AML_Theme.json`.

## 2. Cấu trúc dashboard hợp nhất

- Chỉ một trang hiển thị: `IBM AML — Unified Dashboard`.
- Sáu KPI tổng quan đặt ở đầu trang.
- Bảy khu vực phân tích đánh số `01`–`07`, mỗi khu vực có tiêu đề giải thích biểu đồ và câu hỏi nghiệp vụ.
- Các trang cũ được ẩn trong Reading view nhưng giữ lại để rollback.

## 3. KPI tổng quan

- 6 cards: transaction, laundering, AML rate, cross-bank, cross-currency, self-transfer.
- Line chart: transaction trend.
- Column/bar chart: AML theo payment format.
- Slicer: Date, Payment Currency, Payment Format.
- Overall cards lấy từ `kpi_overview`; slicer chỉ tác động visual trend.

## 4. Khu vực 01 — Transaction Trend

- 4 cards phản ứng với slicer.
- Combo chart: transactions và AML theo date; AML dùng secondary axis.
- Cumulative transaction line.
- Transactions by Payment Format.
- Daily detail table.
- Drill hierarchy Year → Quarter → Month → Date.

## 5. Khu vực 02 và 06 — AML Risk

- AML transaction và AML rate.
- AML by Payment Format.
- AML trend.
- Top 20 risk accounts.
- Conditional formatting đỏ cho participation cao.
- Tooltip gồm bank, account, entity, sent, received và total.

## 6. Khu vực 03 — Bank Activity

- Bank participations.
- AML participations.
- Top 15 bank bar chart.
- Sent vs Received stacked/clustered chart.
- Ranking table Top 50.
- Ghi rõ participation không phải transaction duy nhất.

## 7. Khu vực 04 — Currency Flow

- Matrix Payment Currency × Receiving Currency.
- Conditional background theo transaction count.
- Top currency pairs.
- AML rate theo currency pair.
- Amount chỉ được xem trong ngữ cảnh từng currency.
- Không tạo card tổng amount qua nhiều currency.

## 8. Khu vực 05 — Laundering Pattern

- Pattern attempts.
- Pattern transactions.
- Transactions per attempt.
- Pattern ranking.
- Min/max sequence.
- Không join pattern summary trực tiếp với daily transaction.

## 9. Khu vực 07 — ETL & Data Quality

- Batch count, failed batch, rejected rows, validation pass rate.
- Batch history.
- Validation detail theo batch.
- Conditional color đỏ nếu Failed/Rejected > 0.
- Sort batch giảm dần.

## 10. Interaction

- Chọn **View → Fit to width** để đọc dashboard theo chiều dọc.
- Nếu bổ sung slicer, đặt ở đầu trang và kiểm tra interaction với từng visual.
- Không để slicer làm thay đổi sáu KPI toàn kỳ lấy từ `kpi_overview`.
- Edit interactions để overall KPI cards không bị slicer tác động.
- Slicer Account chỉ dùng trang AML Risk.
- Batch slicer chỉ tác động ETL/Validation.

## 11. Accessibility

- Mỗi visual có title mô tả rõ.
- Alt text cho chart quan trọng.
- Không chỉ dùng màu để phân biệt trạng thái.
- Dùng icon/text PASS/FAILED cùng màu.
- Tab order theo trái → phải, trên → dưới.
