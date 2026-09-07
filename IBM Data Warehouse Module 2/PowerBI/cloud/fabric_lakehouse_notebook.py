# Fabric Notebook / PySpark
# Attach this notebook to the lakehouse IBM_AML_Lakehouse before running.
# Upload the 16 CSV files to Files/IBM_AML/ in the Lakehouse first.

from pyspark.sql import functions as F


TABLES = [
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

LONG_COLUMNS = {
    "dim_date": ["date_key", "year_number", "quarter_number", "month_number", "year_month_sort",
                 "week_of_year", "day_of_month", "day_of_week"],
    "dim_payment_currency": ["payment_currency_key"],
    "dim_receiving_currency": ["receiving_currency_key"],
    "dim_payment_format": ["payment_format_key"],
    "dim_bank": ["bank_key", "bank_id"],
    "dim_pattern_type": ["pattern_type_key"],
    "kpi_overview": ["overview_key", "transaction_count", "laundering_count", "cross_bank_count",
                     "cross_currency_count", "self_transfer_count"],
    "fact_daily_transaction": ["date_key", "payment_currency_key", "payment_format_key",
                               "transaction_count", "laundering_count"],
    "fact_aml_payment_format": ["payment_format_key", "transaction_count", "laundering_count"],
    "fact_bank_activity": ["bank_key", "sent_count", "received_count", "total_participations",
                           "laundering_participations"],
    "fact_currency_flow": ["payment_currency_key", "receiving_currency_key", "transaction_count",
                           "laundering_count"],
    "fact_pattern_summary": ["pattern_type_key", "attempt_count", "pattern_transaction_count",
                             "min_sequence", "max_sequence"],
    "fact_aml_account_risk": ["account_key", "bank_key", "laundering_sent_count",
                              "laundering_received_count", "laundering_participations"],
    "etl_batch_monitor": ["dw_batch_id", "source_low_watermark", "source_high_watermark",
                          "pattern_low_watermark", "pattern_high_watermark",
                          "transaction_rows_inserted", "pattern_rows_inserted", "rejected_rows"],
    "etl_validation_result": ["validation_result_id", "dw_batch_id"],
    "data_quality_overview": ["latest_batch_id", "latest_rejected_rows", "validation_batch_id",
                              "validation_check_count", "validation_passed_count",
                              "validation_failed_count"],
}

DOUBLE_COLUMNS = {
    "kpi_overview": ["laundering_rate_percent"],
    "fact_daily_transaction": ["laundering_rate_percent", "total_amount_paid"],
    "fact_aml_payment_format": ["laundering_rate_percent"],
    "fact_currency_flow": ["total_amount_paid", "total_amount_received"],
    "etl_batch_monitor": ["duration_minutes"],
    "etl_validation_result": ["source_value", "target_value", "difference_value"],
}

DATE_COLUMNS = {
    "dim_date": ["full_date"],
    "kpi_overview": ["min_transaction_date", "max_transaction_date"],
}


def cast_columns(df, table_name):
    for column_name in LONG_COLUMNS.get(table_name, []):
        if column_name in df.columns:
            df = df.withColumn(column_name, F.col(column_name).cast("long"))
    for column_name in DOUBLE_COLUMNS.get(table_name, []):
        if column_name in df.columns:
            df = df.withColumn(column_name, F.col(column_name).cast("double"))
    for column_name in DATE_COLUMNS.get(table_name, []):
        if column_name in df.columns:
            df = df.withColumn(column_name, F.to_date(F.col(column_name), "yyyy-MM-dd"))
    if table_name == "dim_date" and "is_weekend" in df.columns:
        df = df.withColumn(
            "is_weekend",
            F.lower(F.col("is_weekend")).isin("true", "t", "1", "yes", "y"),
        )
    return df


for table_name in TABLES:
    source_path = f"Files/IBM_AML/{table_name}.csv"
    source_df = (
        spark.read
        .option("header", True)
        .option("encoding", "UTF-8")
        .option("mode", "FAILFAST")
        .csv(source_path)
    )
    typed_df = cast_columns(source_df, table_name)
    (
        typed_df.write
        .format("delta")
        .mode("overwrite")
        .option("overwriteSchema", "true")
        .saveAsTable(table_name)
    )
    print(f"{table_name}: {typed_df.count():,} rows")

print("All 16 IBM AML Lakehouse tables were created successfully.")
