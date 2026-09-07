# Báo cáo khảo sát dữ liệu nguồn – IBM AML HI-Medium

Thời điểm tạo: 2026-07-20T23:47:47

## 1. Thống kê tổng quan

| metric | value |
| --- | --- |
| transaction_count | 31898238 |
| min_timestamp | 2022-09-01 00:00:00 |
| max_timestamp | 2022-09-28 15:58:00 |
| laundering_count | 35230 |
| cross_bank_count | 29092624 |
| same_bank_count | 2805614 |
| cross_currency_count | 485144 |
| same_currency_count | 31413094 |
| self_transfer_count | 2561860 |
| account_master_rows | 2087786 |
| account_business_keys | 2087786 |
| bank_master_count | 122333 |
| entity_count | 668138 |
| pattern_transaction_count | 22743 |
| pattern_attempt_count | 2756 |
| pattern_type_count | 8 |
| laundering_rate_percent | 0.110445 |
| active_account_count | 2077023 |
| active_bank_count | 122333 |
| active_accounts_missing_master | 0 |

## 2. Chất lượng dữ liệu

| metric | value |
| --- | --- |
| invalid_timestamp_count | 0 |
| missing_from_bank_count | 0 |
| missing_from_account_count | 0 |
| missing_to_bank_count | 0 |
| missing_to_account_count | 0 |
| invalid_amount_paid_count | 0 |
| invalid_amount_received_count | 0 |
| nonpositive_amount_paid_count | 0 |
| nonpositive_amount_received_count | 0 |
| missing_payment_currency_count | 0 |
| missing_receiving_currency_count | 0 |
| missing_payment_format_count | 0 |
| invalid_laundering_label_count | 0 |
| same_currency_amount_mismatch_count | 0 |

## 3. Phương thức thanh toán

| payment_format | transaction_count | laundering_count | laundering_rate_percent |
| --- | --- | --- | --- |
| Cheque | 12280058 | 2220 | 0.018078 |
| Credit Card | 8777816 | 1354 | 0.015425 |
| ACH | 3868410 | 30746 | 0.794797 |
| Cash | 3217531 | 666 | 0.020699 |
| Reinvestment | 1945611 | 0 | 0.0 |
| Wire | 1119774 | 0 | 0.0 |
| Bitcoin | 689038 | 244 | 0.035412 |

## 4. Hoạt động theo ngày

| transaction_date | transaction_count | laundering_count | sender_bank_count | receiver_bank_count |
| --- | --- | --- | --- | --- |
| 2022-09-01 | 4465985 | 1056 | 77502 | 60612 |
| 2022-09-02 | 3021258 | 1331 | 65186 | 9138 |
| 2022-09-03 | 828958 | 1373 | 6361 | 6646 |
| 2022-09-04 | 830607 | 1549 | 6390 | 6651 |
| 2022-09-05 | 1928599 | 1863 | 6417 | 6710 |
| 2022-09-06 | 1929090 | 2041 | 6426 | 6710 |
| 2022-09-07 | 1931015 | 2147 | 6434 | 6708 |
| 2022-09-08 | 1930610 | 2154 | 6437 | 6711 |
| 2022-09-09 | 2621004 | 2199 | 65186 | 9137 |
| 2022-09-10 | 831874 | 2081 | 6390 | 6648 |
| 2022-09-11 | 830143 | 1966 | 6378 | 6646 |
| 2022-09-12 | 1930240 | 2179 | 6453 | 6711 |
| 2022-09-13 | 1928626 | 2275 | 6432 | 6708 |
| 2022-09-14 | 1930957 | 2263 | 6447 | 6710 |
| 2022-09-15 | 1930419 | 2253 | 6426 | 6710 |
| 2022-09-16 | 3021866 | 2416 | 65184 | 9139 |
| 2022-09-17 | 2020 | 1199 | 665 | 912 |
| 2022-09-18 | 1591 | 916 | 571 | 808 |
| 2022-09-19 | 1195 | 695 | 447 | 654 |
| 2022-09-20 | 855 | 492 | 355 | 513 |
| 2022-09-21 | 586 | 336 | 226 | 363 |
| 2022-09-22 | 309 | 184 | 125 | 215 |
| 2022-09-23 | 134 | 84 | 42 | 111 |
| 2022-09-24 | 104 | 65 | 35 | 88 |
| 2022-09-25 | 102 | 59 | 28 | 79 |
| 2022-09-26 | 59 | 37 | 18 | 49 |
| 2022-09-27 | 25 | 14 | 8 | 22 |
| 2022-09-28 | 7 | 3 | 1 | 4 |

## 5. Các mẫu rửa tiền

| pattern_type | attempt_count | transaction_count | min_sequence | max_sequence |
| --- | --- | --- | --- | --- |
| BIPARTITE | 369 | 2135 | 1 | 15 |
| CYCLE | 367 | 2235 | 1 | 13 |
| FAN-IN | 355 | 2315 | 1 | 16 |
| FAN-OUT | 345 | 2128 | 1 | 16 |
| STACK | 336 | 3986 | 1 | 30 |
| RANDOM | 331 | 1667 | 1 | 12 |
| SCATTER-GATHER | 331 | 3988 | 1 | 32 |
| GATHER-SCATTER | 322 | 4289 | 1 | 31 |

## 6. Top ngân hàng theo số lượt tham gia giao dịch

| bank_id | bank_name | sent_count | received_count | total_participations |
| --- | --- | --- | --- | --- |
| 70 | National Bank of Indianapolis | 2960783 | 18528 | 2979311 |
| 12 | France Bank #62 | 166485 | 74056 | 240541 |
| 11 | Bank of Miami | 164584 | 71382 | 235966 |
| 27 | UK Bank #1 | 149819 | 84132 | 233951 |
| 0 | Hearthstone Bancorp | 159908 | 61261 | 221169 |
| 20 | National Bank of Los Angeles | 157093 | 58812 | 215905 |
| 112 | Mexico Bank #27 | 98772 | 58720 | 157492 |
| 29 | Australia Bank #3 | 91374 | 48049 | 139423 |
| 14 | Spain Bank #32 | 93344 | 42204 | 135548 |
| 15 | Russia Bank #72 | 85704 | 48994 | 134698 |
| 4 | India Bank #45 | 83707 | 47570 | 131277 |
| 114 | Brazil Bank #49 | 79976 | 47860 | 127836 |
| 25 | China Bank #23 | 85366 | 42344 | 127710 |
| 3 | Spain Bank #56 | 84230 | 38245 | 122475 |
| 6 | UK Bank #32 | 75996 | 40451 | 116447 |
| 111 | Australia Bank #53 | 71519 | 38167 | 109686 |
| 2310 | Sunrise Community Bank | 75445 | 33197 | 108642 |
| 113 | Brazil Bank #0 | 70114 | 37101 | 107215 |
| 214 | First Bank of Dallas | 75480 | 30919 | 106399 |
| 1208 | Savings Bank of the South | 74440 | 30100 | 104540 |

## 7. Các cặp tiền tệ phổ biến

| payment_currency | receiving_currency | transaction_count | laundering_count | total_amount_paid | total_amount_received |
| --- | --- | --- | --- | --- | --- |
| US Dollar | US Dollar | 11430671 | 14292 | 3554439156031.71000000 | 3554439156031.71000000 |
| Euro | Euro | 7210831 | 9710 | 1749869663569.58000000 | 1749869663569.58000000 |
| Yuan | Yuan | 2258494 | 2775 | 4587061703304.20000000 | 4587061703304.20000000 |
| Shekel | Shekel | 1407929 | 658 | 1519911189358.99000000 | 1519911189358.99000000 |
| Canadian Dollar | Canadian Dollar | 1072557 | 605 | 385951716257.59000000 | 385951716257.59000000 |
| UK Pound | UK Pound | 1003299 | 1629 | 202667249310.63000000 | 202667249310.63000000 |
| Ruble | Ruble | 973167 | 1457 | 48939463332319.22000000 | 48939463332319.22000000 |
| Australian Dollar | Australian Dollar | 916834 | 737 | 419013220477.62000000 | 419013220477.62000000 |
| Yen | Yen | 845439 | 1114 | 52571574583608.09000000 | 52571574583608.09000000 |
| Swiss Franc | Swiss Franc | 843096 | 330 | 208692477727.12000000 | 208692477727.12000000 |
| Mexican Peso | Mexican Peso | 838922 | 346 | 4802431357670.27000000 | 4802431357670.27000000 |
| Rupee | Rupee | 730221 | 830 | 18501473022631.61000000 | 18501473022631.61000000 |
| Bitcoin | Bitcoin | 688694 | 244 | 23885072.35579500 | 23885072.35579500 |
| Brazil Real | Brazil Real | 628744 | 279 | 968186437910.41000000 | 968186437910.41000000 |
| Saudi Riyal | Saudi Riyal | 564196 | 224 | 615532749868.35000000 | 615532749868.35000000 |
| US Dollar | Euro | 104209 | 0 | 22671455057.83000000 | 19347819746.15000000 |
| Euro | US Dollar | 81120 | 0 | 40574397670.07000000 | 47544407864.41000000 |
| Yuan | US Dollar | 51333 | 0 | 24951205997.90000000 | 3725395068.18000000 |
| US Dollar | Yuan | 30457 | 0 | 52536439378.37000000 | 351868056366.86000000 |
| US Dollar | Shekel | 15152 | 0 | 8566493242.02000000 | 28929047683.27000000 |
| US Dollar | UK Pound | 12588 | 0 | 1801665647.15000000 | 1394849542.85000000 |
| US Dollar | Canadian Dollar | 12239 | 0 | 3392207658.49000000 | 4475339564.26000000 |
| US Dollar | Ruble | 11975 | 0 | 222495476503.36000000 | 17311038053948.89000000 |
| US Dollar | Yen | 10965 | 0 | 266002379001.49000000 | 28036650747001.65000000 |
| US Dollar | Australian Dollar | 10731 | 0 | 5553763760.60000000 | 7846357438.05000000 |
| UK Pound | US Dollar | 10263 | 0 | 1725262121.15000000 | 2228444999.35000000 |
| US Dollar | Swiss Franc | 9899 | 0 | 1480293146.41000000 | 1354468228.46000000 |
| US Dollar | Mexican Peso | 9646 | 0 | 20991434205.91000000 | 443823992616.43000000 |
| US Dollar | Rupee | 8948 | 0 | 44672272477.74000000 | 3280910379909.93000000 |
| US Dollar | Bitcoin | 7347 | 0 | 254455.05000000 | 21.41508600 |

## 8. Kết luận kỹ thuật

- Bank ID trong transaction có thể có số 0 ở đầu; khi liên kết với account master cần chuẩn hóa về giá trị số rồi chuyển lại thành chuỗi.
- Khóa nghiệp vụ tài khoản phải là `(BankID đã chuẩn hóa, AccountNumber)`.
- Mọi tổng tiền phải giữ currency trong grain; không cộng trực tiếp nhiều currency.
- `Is Laundering` là ground truth synthetic và cần được tách biệt với alert hoặc prediction trong các giai đoạn sau.
