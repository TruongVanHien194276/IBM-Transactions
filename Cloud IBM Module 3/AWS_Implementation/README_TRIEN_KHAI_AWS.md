# Hướng dẫn triển khai IBM AML trên AWS – mức basic, thao tác Console

> Phạm vi: Proof of Concept batch analytics, không viết PySpark. Glue Visual ETL là giao diện kéo-thả nhưng dịch vụ vẫn sinh job Spark phía sau.
>
> Trạng thái hiện tại: bucket `ibm-aml-basic-huydungle-20260819`, các prefix và Glue database `ibm_aml_raw` đã được tạo tại Singapore. Crawler chưa tạo được do tài khoản báo `Account 739515567332 is denied access`.

## 1. Kiến trúc mục tiêu

`CSV → S3 raw → Glue Crawler/Data Catalog → Glue Visual ETL → S3 curated Parquet → Athena → Power BI`

- S3: lưu raw, curated, temporary và Athena results.
- Glue Data Catalog/Crawler: quản lý metadata/schema.
- Glue Studio Visual ETL: kéo-thả biến đổi dữ liệu.
- Athena: SQL serverless trên S3.
- Power BI: dashboard; trên macOS dùng Power BI Service/web hoặc máy Windows từ xa.
- CloudWatch: log và giám sát Glue.

## 2. Chuẩn bị và giới hạn chi phí

1. Chọn region **Asia Pacific (Singapore) – ap-southeast-1**.
2. Đăng nhập bằng user/role được phép dùng S3, Glue, IAM PassRole và Athena.
3. Không dùng root account cho thao tác hằng ngày.
4. Chạy bằng file sample trước; không upload/chạy full 31.9 triệu dòng ngay.
5. Ghi lại thời gian chạy và dọn temporary/query results sau demo.

## 3. Cấu trúc S3

Trong bucket, kiểm tra/tạo các prefix:

```text
ibm-aml-basic-huydungle-20260819/
├── raw/
│   ├── accounts/
│   ├── transactions/
│   └── patterns/
├── curated/
│   ├── dim_account/
│   ├── fact_transaction/
│   └── bridge_pattern_transaction/
├── temporary/
└── athena-results/
```

Thiết lập cơ bản:

- Giữ **Block all public access** bật.
- Giữ encryption at rest mặc định hoặc SSE-KMS nếu có yêu cầu quản trị khóa.
- Không sửa đè raw; file mới dùng tên có ngày hoặc `ingest_date`.
- Tạo lifecycle cho `temporary/` và `athena-results/` sau khi hoàn tất demo.

Upload sample đúng thư mục:

- Accounts CSV → `raw/accounts/`
- Transactions CSV → `raw/transactions/`
- Patterns CSV → `raw/patterns/`

## 4. IAM role cho Glue

Trong bước tạo crawler, có thể chọn **Create default role** và đặt tên:

`AWSGlueServiceRole-ibm-aml-basic`

Nếu lab/account không cho tạo role, nhờ admin tạo role có trust principal `glue.amazonaws.com` và quyền tối thiểu:

- Đọc `s3://ibm-aml-basic-huydungle-20260819/raw/*`
- Đọc/ghi `curated/*` và `temporary/*`
- Ghi/đọc Glue Data Catalog theo database của project
- Ghi CloudWatch Logs
- Với người tạo job/crawler: có quyền `iam:PassRole` cho đúng role này

Không gắn AdministratorAccess chỉ để vượt lỗi.

## 5. Glue database và crawler raw

Database hiện có: `ibm_aml_raw`.

Tạo crawler:

1. AWS Glue → Data Catalog → Crawlers → Create crawler.
2. Name: `ibm-aml-raw-crawler`.
3. Data source: S3.
4. Include paths:
   - `s3://ibm-aml-basic-huydungle-20260819/raw/accounts/`
   - `s3://ibm-aml-basic-huydungle-20260819/raw/transactions/`
   - `s3://ibm-aml-basic-huydungle-20260819/raw/patterns/`
5. IAM role: `AWSGlueServiceRole-ibm-aml-basic`.
6. Target database: `ibm_aml_raw`.
7. Schedule: On demand cho PoC.
8. Create crawler → Run crawler.

Sau khi status là **Ready/Succeeded**, vào Tables và kiểm tra:

- Mỗi dataset tạo đúng một bảng.
- Location trỏ đúng prefix, không trỏ ở `raw/` quá cao làm trộn schema.
- Header không bị hiểu thành dữ liệu.
- Timestamp, amount, boolean/AML flag có kiểu hợp lý.
- Đổi tên cột chuẩn hóa nếu crawler tạo tên khó dùng.

## 6. Xử lý lỗi account denied access

Thông báo hiện gặp:

`Account 739515567332 is denied access.`

Checklist xử lý:

1. Xác định lỗi xuất hiện khi **create role**, **PassRole** hay **CreateCrawler**.
2. Kiểm tra IAM policy của user/role đang đăng nhập.
3. Kiểm tra permission boundary, AWS Organizations SCP hoặc giới hạn tài khoản lab.
4. Nếu là tài khoản do trường/lab cấp, gửi admin ảnh lỗi, account ID, region, crawler name và timestamp.
5. Yêu cầu cấp đúng quyền thay vì yêu cầu quyền admin toàn tài khoản.
6. Sau khi mở quyền, tạo lại crawler; không cần xóa bucket/raw data.

## 7. Glue Studio Visual ETL – transaction job

Tạo job: AWS Glue → ETL jobs → Visual ETL → Visual with a source and target.

Tên job: `ibm-aml-transaction-curated`.

### Node 1 – Source

- Source: AWS Glue Data Catalog.
- Database: `ibm_aml_raw`.
- Table: transaction raw table.

### Node 2 – Change Schema

- Chuẩn hóa tên cột về snake_case.
- Cast timestamp về timestamp.
- Cast amount về decimal phù hợp; không dùng float cho số tiền nếu có thể.
- Cast `is_laundering` về integer/boolean.

### Node 3 – Derived Column

Tạo:

- `txn_date` từ timestamp.
- `is_cross_bank` = source_bank khác destination_bank.
- `is_self_transfer` = source_account bằng destination_account.
- `is_cross_currency` = source_currency khác destination_currency.
- `ingest_date` hoặc `run_id` để truy vết lần chạy.

### Node 4 – Filter / validation

Record hợp lệ:

- transaction key không null.
- timestamp parse được.
- amount > 0.
- is_laundering thuộc 0/1.

Record lỗi nên ghi riêng vào `curated/rejects/transaction/` hoặc `temporary/rejects/`, không xóa im lặng.

### Node 5 – Join (tùy chọn)

Join account master nếu cần thuộc tính bổ sung. Trước và sau join phải kiểm tra row count để tránh nhân bản fact.

### Node 6 – Target

- Format: Parquet.
- Compression: Snappy.
- Target: `s3://ibm-aml-basic-huydungle-20260819/curated/fact_transaction/`
- Partition key: `txn_date` cho PoC nhỏ; khi nhiều năm cân nhắc `txn_year`, `txn_month`, `txn_day`.
- Temporary path: `s3://ibm-aml-basic-huydungle-20260819/temporary/`

Job details:

- IAM role: role Glue ở trên.
- Giữ worker nhỏ nhất phù hợp khi chạy sample.
- Timeout và retry ở mức thấp trong PoC để tránh chi phí ngoài ý muốn.
- Save → Run.

Gate nghiệm thu:

- Job status Succeeded.
- `raw_count = valid_count + rejected_count`.
- AML count, min/max timestamp, phân bố theo ngày khớp baseline local.
- Output là Parquet và có partition mong muốn.

## 8. Catalog curated

Tạo database `ibm_aml_curated` và crawler `ibm-aml-curated-crawler` cho:

`s3://ibm-aml-basic-huydungle-20260819/curated/`

Chạy crawler sau khi Visual ETL đã ghi output. Kiểm tra grain và data type trước khi dùng Athena.

## 9. Athena

1. Mở Athena, giữ region Singapore.
2. Settings → Manage → Query result location:
   `s3://ibm-aml-basic-huydungle-20260819/athena-results/`
3. Chọn Data source `AwsDataCatalog`.
4. Chọn database `ibm_aml_curated`.
5. Chạy query kiểm tra `LIMIT 10`, sau đó KPI trong file `ATHENA_KPI_QUERIES.sql`.
6. Luôn dùng điều kiện partition/date trong truy vấn lớn.

Đối soát bắt buộc với local:

- Total transactions.
- AML transactions và AML rate.
- Cross-bank/self-transfer/cross-currency count.
- Count theo payment format.
- Daily count và min/max date.

## 10. Power BI

Phương án đơn giản:

- Athena ODBC connector trên máy Windows/VM có Power BI Desktop; hoặc
- Xuất Athena result/curated dataset để publish vào Power BI Service theo giới hạn môi trường lớp học.

Trong production nên dùng account/service principal, gateway/refresh phù hợp và chỉ expose view curated. Không đưa access key AWS vào slide hoặc file nộp.

## 11. Workflow/trigger cơ bản

PoC có thể chạy tay. Nếu cần mô tả orchestration:

1. Trigger crawler raw khi file đến hoặc theo lịch.
2. Khi crawler thành công, chạy Visual ETL.
3. Khi ETL thành công, chạy crawler curated.
4. Refresh view/dataset BI.
5. Nếu bất kỳ bước nào Failed, ghi CloudWatch log và thông báo người vận hành.

Thiết kế idempotent: chạy lại cùng partition không được append trùng.

## 12. Checklist demo

- [ ] Region là ap-southeast-1.
- [ ] S3 raw/curated/temporary/athena-results đúng cấu trúc.
- [ ] Block Public Access bật.
- [ ] Glue database/crawler/table hiển thị đúng.
- [ ] Visual ETL canvas có source → transform → target.
- [ ] Job sample Succeeded và có output Parquet.
- [ ] Athena query có kết quả và đúng baseline local.
- [ ] Dashboard hiển thị 3 insight chính.
- [ ] Không để lộ account secret/access key.
- [ ] Nếu chưa chạy được, nói rõ “proposed PoC” và trình bày lỗi quyền.

## 13. Cleanup sau demo

1. Dừng schedule/trigger để không phát sinh run ngoài ý muốn.
2. Xóa Glue job/crawler thử nghiệm nếu không dùng tiếp.
3. Xóa object trong `temporary/` và `athena-results/` khi đã lưu bằng chứng cần thiết.
4. Chỉ xóa bucket/raw khi chắc chắn không cần nộp/chứng minh; thao tác này không thể hoàn tác dễ dàng.
5. Kiểm tra Billing/Cost Explorer nếu tài khoản cho phép.
