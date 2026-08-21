/* Chỉ chạy sau khi 06_validate_source.sql đã đạt
Giảm kích thước database và backup */

TRUNCATE TABLE
    raw.transaction_landing,
    raw.account_landing,
    raw.pattern_transaction_landing
RESTART IDENTITY;

VACUUM (ANALYZE) raw.transactions;
VACUUM (ANALYZE) raw.account;
VACUUM (ANALYZE) raw.laundering_pattern_transaction;
