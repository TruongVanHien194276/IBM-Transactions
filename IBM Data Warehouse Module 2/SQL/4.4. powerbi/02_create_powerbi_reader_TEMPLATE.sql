/*
Chạy file trong DBeaver bằng user quản trị PostgreSQL

Note:
1. Đổi REPLACE_WITH_A_STRONG_LOCAL_PASSWORD thành mật khẩu 
2. Tài khoản chỉ có SELECT trên schema pbi
*/

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'powerbi_reader') THEN
        CREATE ROLE powerbi_reader
            LOGIN
            PASSWORD 'REPLACE_WITH_A_STRONG_LOCAL_PASSWORD';
    ELSE
        ALTER ROLE powerbi_reader
            LOGIN
            PASSWORD 'REPLACE_WITH_A_STRONG_LOCAL_PASSWORD';
    END IF;
END
$$;

GRANT powerbi_readonly TO powerbi_reader;

SELECT
    r.rolname,
    r.rolcanlogin,
    pg_has_role('powerbi_reader', 'powerbi_readonly', 'member') AS is_readonly_member
FROM pg_roles r
WHERE r.rolname = 'powerbi_reader';

