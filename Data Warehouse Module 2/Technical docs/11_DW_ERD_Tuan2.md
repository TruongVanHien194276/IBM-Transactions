# Data Warehouse ERD – IBM AML HI-Medium

```mermaid
erDiagram
    DIM_DATE ||--o{ FACT_TRANSACTION : date_key
    DIM_TIME ||--o{ FACT_TRANSACTION : time_key
    DIM_BANK ||--o{ FACT_TRANSACTION : from_bank_key
    DIM_BANK ||--o{ FACT_TRANSACTION : to_bank_key
    DIM_ACCOUNT ||--o{ FACT_TRANSACTION : from_account_key
    DIM_ACCOUNT ||--o{ FACT_TRANSACTION : to_account_key
    DIM_ENTITY ||--o{ FACT_TRANSACTION : from_entity_key
    DIM_ENTITY ||--o{ FACT_TRANSACTION : to_entity_key
    DIM_CURRENCY ||--o{ FACT_TRANSACTION : payment_currency_key
    DIM_CURRENCY ||--o{ FACT_TRANSACTION : receiving_currency_key
    DIM_PAYMENT_FORMAT ||--o{ FACT_TRANSACTION : payment_format_key

    DIM_BANK ||--o{ DIM_ACCOUNT : bank_key
    DIM_ENTITY ||--o{ DIM_ACCOUNT : entity_key

    DIM_DATE ||--o{ FACT_PATTERN_TRANSACTION : date_key
    DIM_TIME ||--o{ FACT_PATTERN_TRANSACTION : time_key
    DIM_PATTERN_TYPE ||--o{ FACT_PATTERN_TRANSACTION : pattern_type_key
    DIM_BANK ||--o{ FACT_PATTERN_TRANSACTION : sender_receiver
    DIM_ACCOUNT ||--o{ FACT_PATTERN_TRANSACTION : sender_receiver
    DIM_CURRENCY ||--o{ FACT_PATTERN_TRANSACTION : paid_received
    DIM_PAYMENT_FORMAT ||--o{ FACT_PATTERN_TRANSACTION : payment_format_key

    FACT_TRANSACTION {
        bigint transaction_key PK
        int date_key
        int time_key
        bigint from_bank_key
        bigint to_bank_key
        bigint from_account_key
        bigint to_account_key
        bigint from_entity_key
        bigint to_entity_key
        smallint payment_currency_key
        smallint receiving_currency_key
        smallint payment_format_key
        numeric amount_paid
        numeric amount_received
        boolean is_laundering
        boolean is_cross_bank
        boolean is_cross_currency
        boolean is_self_transfer
    }

    DIM_ACCOUNT {
        bigint account_key PK
        text bank_id BK
        text account_number BK
        bigint bank_key FK
        bigint entity_key FK
        timestamptz effective_from
        timestamptz effective_to
        boolean is_current
    }

    FACT_PATTERN_TRANSACTION {
        bigint pattern_transaction_key PK
        bigint pattern_attempt_id
        smallint pattern_type_key
        int pattern_sequence
        numeric amount_paid
        numeric amount_received
    }
```

## Ghi chú

- Các quan hệ sender/receiver là role-playing dimension.
- Fact transaction giữ grain nguyên tử, không aggregate trước khi nạp.
- Quan hệ logical của fact lớn được kiểm tra bằng ETL validation thay vì FK vật lý trên từng dòng.
- `dim_account` là SCD Type 2; fact lookup version đang hiệu lực trong dataset hiện tại.

