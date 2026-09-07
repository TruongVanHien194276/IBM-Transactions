# Fabric Notebook / PySpark validation
# Run after fabric_lakehouse_notebook.py.

from pyspark.sql import functions as F


EXPECTED_TABLES = [
    "dim_date",
    "dim_payment_currency",
    "dim_receiving_currency",
    "dim_payment_format",
    "dim_bank",
    "dim_pattern_type",
    "kpi_overview",
    "fact_daily_transaction",
    "fact_aml_payment_format",
    "fact_bank_activity",
    "fact_currency_flow",
    "fact_pattern_summary",
    "fact_aml_account_risk",
    "etl_batch_monitor",
    "etl_validation_result",
    "data_quality_overview",
]

actual_tables = {row.tableName for row in spark.sql("SHOW TABLES").collect()}
missing = sorted(set(EXPECTED_TABLES) - actual_tables)
assert not missing, f"Missing Lakehouse tables: {missing}"

kpi = spark.table("kpi_overview").first().asDict()
assert int(kpi["transaction_count"]) == 31_898_238
assert int(kpi["laundering_count"]) == 35_230
assert int(kpi["cross_bank_count"]) == 29_092_624
assert int(kpi["cross_currency_count"]) == 485_144
assert int(kpi["self_transfer_count"]) == 2_561_860

assert spark.table("dim_date").count() == 28
assert spark.table("fact_aml_payment_format").count() == 7
assert spark.table("fact_currency_flow").count() == 223
assert spark.table("fact_pattern_summary").count() == 8
assert spark.table("fact_aml_account_risk").count() == 41_857
assert spark.table("fact_bank_activity").count() == 122_333

daily_total = (
    spark.table("fact_daily_transaction")
    .agg(F.sum("transaction_count").alias("transaction_count"))
    .first()["transaction_count"]
)
assert int(daily_total) == 31_898_238

print("PASS: 16 tables exist, row counts are correct, and KPI reconciliation succeeded.")
