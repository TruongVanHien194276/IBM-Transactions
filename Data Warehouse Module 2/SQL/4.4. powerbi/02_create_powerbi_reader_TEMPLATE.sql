/*
Chạy file này trong DBeaver bằng user quản trị PostgreSQL.

QUAN TRỌNG:
1. Đổi REPLACE_WITH_A_STRONG_LOCAL_PASSWORD thành mật khẩu do bạn tự chọn.
2. Không đưa mật khẩu thật vào Git, báo cáo, ảnh chụp hoặc file ZIP nộp bài.
3. Tài khoản chỉ có SELECT trên schema pbi.
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

