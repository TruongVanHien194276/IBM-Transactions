/*
Chạy file này trong DBeaver khi đang kết nối database postgres
Bật Auto-commit vì CREATE DATABASE không được chạy bên trong transaction
Nếu database aml_source đã tồn tại thì bỏ qua file này
*/

CREATE DATABASE aml_source
    WITH
    ENCODING = 'UTF8'
    TEMPLATE = template0;
