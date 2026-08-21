let
    // Đổi VIEW_NAME thành tên view trong schema pbi.
    Source = PostgreSQL.Database("localhost", "aml_source", [CreateNavigationProperties=false]),
    Data = Source{[Schema="pbi", Item="VIEW_NAME"]}[Data]
in
    Data
