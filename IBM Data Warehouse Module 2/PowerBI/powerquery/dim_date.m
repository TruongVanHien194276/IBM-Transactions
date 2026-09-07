let
    Source = PostgreSQL.Database("localhost", "aml_source", [CreateNavigationProperties=false]),
    Data = Source{[Schema="pbi", Item="dim_date"]}[Data],
    Typed = Table.TransformColumnTypes(Data, {
        {"date_key", Int64.Type},
        {"full_date", type date},
        {"year_number", Int64.Type},
        {"quarter_number", Int64.Type},
        {"month_number", Int64.Type},
        {"year_month_sort", Int64.Type},
        {"week_of_year", Int64.Type},
        {"day_of_month", Int64.Type},
        {"day_of_week", Int64.Type},
        {"is_weekend", type logical}
    })
in
    Typed
