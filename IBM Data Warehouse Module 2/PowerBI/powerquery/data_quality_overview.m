let
    Source = PostgreSQL.Database("localhost", "aml_source", [CreateNavigationProperties=false]),
    Data = Source{[Schema="pbi", Item="data_quality_overview"]}[Data]
in
    Data
