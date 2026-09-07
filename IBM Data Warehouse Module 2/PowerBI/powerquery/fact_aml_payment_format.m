let
    Source = PostgreSQL.Database("localhost", "aml_source", [CreateNavigationProperties=false]),
    Data = Source{[Schema="pbi", Item="fact_aml_payment_format"]}[Data]
in
    Data
