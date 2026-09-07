let
    Source = PostgreSQL.Database("localhost", "aml_source", [CreateNavigationProperties=false]),
    Data = Source{[Schema="pbi", Item="fact_daily_transaction"]}[Data]
in
    Data
