# Đối soát Power BI - Tuần 3

## 1. Trạng thái PostgreSQL reporting layer

- View count: 16 - PASS.
- KPI validation: PASS.
- Duplicate/missing relationship keys: 10/10 kiểm tra có error count = 0.
- Read-only role: enabled.
- Latest completed batch: PASSED.
- Rejected rows: 0.

## 2. Expected KPI

| KPI | Expected |
|---|---:|
| Transaction count | 31.898.238 |
| Laundering count | 35.230 |
| AML rate | 0,110445% |
| Cross-bank count | 29.092.624 |
| Cross-currency count | 485.144 |
| Self-transfer count | 2.561.860 |
| Min date | 2022-09-01 |
| Max date | 2022-09-28 |

## 3. Expected Power BI table rows

| Object | Rows |
|---|---:|
| dim_date | 28 |
| dim_payment_currency | 15 |
| dim_receiving_currency | 15 |
| dim_payment_format | 7 |
| dim_bank | 122.333 |
| dim_pattern_type | 8 |
| kpi_overview | 1 |
| fact_daily_transaction | 1.420 |
| fact_aml_payment_format | 7 |
| fact_bank_activity | 122.333 |
| fact_currency_flow | 223 |
| fact_pattern_summary | 8 |
| fact_aml_account_risk | 41.857 |

## 4. Power BI acceptance tests

- Overall Transactions = 31.898.238.
- Overall AML = 35.230.
- Overall AML Rate hiển thị khoảng 0,11%.
- Date slicer không làm thay đổi Overall cards.
- Date slicer làm thay đổi dynamic Transaction/AML measures.
- Payment Currency không lọc Receiving Currency dimension.
- Payment Format lọc daily và payment-format summary.
- Bank lọc Bank Activity và Account Risk.
- Batch lọc Validation Detail.
- Amount card blank nếu chưa single-select currency.
- Pattern page không làm thay đổi transaction KPI.

## 5. SQL dùng để kiểm tra

```sql
SELECT * FROM pbi.kpi_overview;
SELECT * FROM pbi.data_quality_overview;
SELECT count(*) FROM pbi.fact_daily_transaction;
SELECT count(*) FROM pbi.fact_aml_account_risk;
SELECT count(*) FROM pbi.fact_bank_activity;
SELECT count(*) FROM pbi.fact_currency_flow;
SELECT count(*) FROM pbi.fact_pattern_summary;
```

