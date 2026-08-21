# Mô tả nghiệp vụ quản lý giao dịch ngân hàng và giám sát AML

## 1. Thông tin đề tài

- Tên đề tài: Xây dựng Data Warehouse phân tích giao dịch ngân hàng và giám sát rửa tiền
- Dataset: IBM Transactions for Anti Money Laundering – HI-Medium.
- Phạm vi tuần 1: khảo sát dữ liệu và xây dựng database nguồn `aml_source`
- Công nghệ: PostgreSQL chạy bằng DBeaver, Power BI

## 2. Bối cảnh nghiệp vụ

Hệ thống mô phỏng một hệ sinh thái tài chính trong đó cá nhân và tổ chức sở hữu tài khoản tại nhiều ngân hàng. Các tài khoản thực hiện chuyển tiền, thanh toán, mua hàng, trả lương, trả nợ và các hoạt động tài chính khác. Một tỷ lệ nhỏ giao dịch được bộ sinh dữ liệu gắn nhãn liên quan đến rửa tiền

Project xây dựng nền tảng dữ liệu để quản lý và phân tích các giao dịch này, tập trung vào dòng tiền giữa tài khoản, giữa ngân hàng, theo thời gian, theo loại tiền tệ, theo phương thức thanh toán và theo nhãn AML

## 3. Đối tượng sử dụng

- Quản lý ngân hàng: xem khối lượng giao dịch và dòng tiền giữa các ngân hàng
- Chuyên viên AML: theo dõi giao dịch có nhãn rửa tiền và các pattern đã biết
- Chuyên viên phân tích: phân tích tài khoản, tiền tệ và phương thức thanh toán
- Data engineer: quản lý chất lưng, truy vết và quy trình nạp dữ liệu.
- Người quản trị hệ thống: vận hành và phân quyền database

## 4. Các thực thể nguồn

### 4.1. Bank

- Được xác định bằng Bank ID sau chuẩn hóa.
- Bank ID trong transaction có thể được đệm số 0 ở đầu
- Khi liên kết, Bank ID được chuyển sang số rồi chuyển lại thành chuỗi chuẩn
- Bank name lấy từ account master

### 4.2. Account

- Một tài khoản thuộc về một ngân hàng
- Khóa nghiệp vụ: `(Normalized Bank ID, Account Number)`
- Không sử dụng riêng Account Number làm khóa toàn hệ thống
- Một account master liên kết đến một entity

### 4.3. Entity

- Đại diện cá nhân hoặc tổ chức sở hữu tài khoản
- Dataset cung cấp Entity ID và Entity Name
- Một entity có thể liên kết với một hoặc nhiều tài khoản; cần xác minh bằng profiling

### 4.4. Transaction

- 1 dòng transaction là một lần chuyển tiền từ tài khoản gửi đến tài khoản nhận
- Transaction chứa hai vai trò: sender và receiver
- Không tách thành hai giao dịch riêng trong database nguồn

### 4.5. Laundering pattern

- File pattern nhóm các giao dịch thành laundering attempt
- Mỗi attempt có loại pattern, mô tả, thứ tự giao dịch và danh sách giao dịch thành phần
- Không phải mọi giao dịch `Is Laundering = 1` đều bắt buộc xuất hiện trong file pattern

## 5. Quy tắc nghiệp vụ

- BR-01: Một transaction có đúng một tài khoản gửi và một tài khoản nhận
- BR-02: Khóa tài khoản là tổ hợp Bank ID đã chuẩn hóa và Account Number
- BR-03: `Amount Paid` luôn được diễn giải cùng `Payment Currency`
- BR-04: `Amount Received` luôn được diễn giải cùng `Receiving Currency`
- BR-05: Không cộng trực tiếp amount thuộc nhiều currency
- BR-06: Khi hai currency khác nhau và amount paid lớn hơn 0, có thể tính `Implied Exchange Rate = Amount Received / Amount Paid`
- BR-07: Implied exchange rate không được gọi là tỷ giá thị trường
- BR-08: Chênh lệch paid/received không tự động được xem là phí
- BR-09: Giao dịch khác ngân hàng khi normalized sender bank khác normalized receiver bank
- BR-10: Giao dịch cross-currency khi payment currency khác receiving currency
- BR-11: Self-transfer khi cả bank và account của sender giống receiver
- BR-12: `Is Laundering` là ground truth synthetic, không phải alert do project sinh ra
- BR-13: Dòng lỗi cấu trúc phải được ghi vào rejected table, không xóa âm thầm
- BR-14: Mỗi bản ghi nguồn phải truy vết được về source row và load batch
- BR-15: File raw không được chỉnh sửa sau khi tải và xác minh checksum

## 6. Các quá trình nghiệp vụ cần phân tích

- Giao dịch theo ngày, giờ và khung giờ
- Gửi và nhận tiền theo ngân hàng
- Hoạt động gửi/nhận của tài khoản
- Dòng tiền nội bộ và liên ngân hàng
- Giao dịch theo currency pair
- Giao dịch theo payment format
- Giao dịch laundering theo thời gian, ngân hàng, tài khoản và phương thức
- Laundering attempt theo pattern type và số hop

## 7. Yêu cầu dữ liệu nguồn

- Timestamp phải parse được
- Bank ID và Account ID bên gửi/nhận không được thiếu
- Amount paid/received phải parse được thành decimal
- Currency và payment format không được trống
- Is Laundering chỉ nhận 0 hoặc 1
- Amount bằng 0, self-transfer hoặc timestamp ngoài khoảng chính là bất thường cần kiểm tra, không mặc định là lỗi phải loại

## 8. Database nguồn `aml_source`

- `raw.account_landing`: account nguyên dạng text, bảng `UNLOGGED`.
- `raw.transaction_landing`: transaction nguyên dạng text, bảng `UNLOGGED`.
- `raw.pattern_transaction_landing`: pattern đã parse trước khi chuyển kiểu.
- `raw.account`: account typed và Bank ID đã chuẩn hóa.
- `raw.transactions`: transaction typed.
- `raw.laundering_pattern_transaction`: pattern transaction có cấu trúc.
- `raw.rejected_row`: dòng bị từ chối cùng lý do và raw payload.
- `etl.load_batch`: theo dõi số dòng, trạng thái và thời gian mỗi lần nạp.
- `src.vw_bank`: danh mục ngân hàng suy ra từ account master.
- `src.vw_transaction_business`: transaction kèm cờ nghiệp vụ.

## 9. Giới hạn của nguồn

- Dữ liệu synthetic, không phải dữ liệu khách hàng thật
- Không có branch, account balance, fee, transaction status hoặc official exchange rate.
- Không có ngày mở/đóng tài khoản
- First seen/last seen chỉ là thời điểm xuất hiện trong dataset
- Khoảng thời gian tương đối ngắn nên không phù hợp kết luận mùa vụ dài hạn
- Tỷ lệ laundering rất thấp; accuracy không phải metric đủ tốt nếu xây mô hình phát hiện
