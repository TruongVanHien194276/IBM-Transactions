let
    Source = PostgreSQL.Database("localhost", "aml_source", [CreateNavigationProperties=false]),
    Data = Source{[Schema="pbi", Item="etl_batch_monitor"]}[Data]
in
    Data
