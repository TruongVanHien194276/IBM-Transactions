# DAX Dictionary - Tuần 3

File triển khai đầy đủ: `powerbi/dax/IBM_AML_Measures.dax`.

## 1. Overview measures

- `Overall Transactions`: tổng transaction toàn kỳ.
- `Overall Laundering Transactions`: tổng laundering toàn kỳ.
- `Overall AML Rate %`: laundering / transaction.
- `Overall Cross-bank Transactions`.
- `Overall Cross-bank Rate %`.
- `Overall Cross-currency Transactions`.
- `Overall Cross-currency Rate %`.
- `Overall Self-transfer Transactions`.
- `Overall Self-transfer Rate %`.
- `Data Start Date`.
- `Data End Date`.
- `Data Period Label`.

## 2. Transaction measures

- `Transactions`: phản ứng với Date/Currency/Payment Format slicer.
- `Laundering Transactions`.
- `AML Rate %`.
- `Amount Paid`.
- `Average Amount per Transaction`.
- `Selected Currency Amount Paid`: chỉ trả kết quả khi chọn đúng một payment currency.
- `Selected Currency Amount Title`.
- `Previous Day Transactions`.
- `Transaction Growth %`.
- `Cumulative Transactions`.

## 3. Bank and account

- `Bank Sent Participations`.
- `Bank Received Participations`.
- `Bank Total Participations`.
- `Bank AML Participations`.
- `Bank AML Participation Rate %`.
- `Bank Activity Rank`.
- `AML Account Sent Participations`.
- `AML Account Received Participations`.
- `AML Account Participations`.
- `AML Account Risk Rank`.

## 4. Currency

- `Currency Flow Transactions`.
- `Currency Flow Laundering`.
- `Currency Flow AML Rate %`.
- `Currency Flow Amount Paid`.
- `Currency Flow Amount Received`.

## 5. Pattern

- `Pattern Attempts`.
- `Pattern Transactions`.
- `Transactions per Pattern Attempt`.
- `Pattern Rank`.

## 6. ETL and validation

- `ETL Batch Count`.
- `ETL Completed Batches`.
- `ETL Failed Batches`.
- `ETL Rejected Rows`.
- `Latest Batch ID`.
- `Latest Batch Duration Minutes`.
- `Validation Checks`.
- `Validation Passed`.
- `Validation Failed`.
- `Validation Pass Rate %`.

## 7. Format

- Count: `#,##0`.
- Amount: `#,##0.00`.
- Rate: `0.00%`.
- Date: `dd/MM/yyyy`.
- Duration: `0.00`.
- Rank: `0`.

