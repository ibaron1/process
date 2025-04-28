-- Only blocking and blocked sessions
WITH BlockingInfo AS (
    SELECT
        r.session_id,
        r.blocking_session_id,
        r.wait_type,
        r.wait_time,
        r.wait_resource,
        DB_NAME(r.database_id) AS database_name,
        s.status,
        s.login_name,
        s.host_name,
        s.program_name,
        r.start_time,
        r.command,
        t.text AS sql_text
    FROM
        sys.dm_exec_requests r
    INNER JOIN
        sys.dm_exec_sessions s ON r.session_id = s.session_id
    OUTER APPLY
        sys.dm_exec_sql_text(r.sql_handle) t
    WHERE
        r.blocking_session_id <> 0 -- only sessions that are blocked
        OR EXISTS (
            -- or sessions that are blocking others
            SELECT 1
            FROM sys.dm_exec_requests r2
            WHERE r2.blocking_session_id = r.session_id
        )
)
SELECT
    *
FROM
    BlockingInfo
ORDER BY
    blocking_session_id, session_id;

	--============================================

-- Blocking Tree
WITH BlockingTree AS (
    SELECT
        r.session_id,
        r.blocking_session_id,
        s.login_name,
        s.host_name,
        s.program_name,
        r.command,
        t.text AS sql_text,
        0 AS Level
    FROM
        sys.dm_exec_requests r
    INNER JOIN
        sys.dm_exec_sessions s ON r.session_id = s.session_id
    OUTER APPLY
        sys.dm_exec_sql_text(r.sql_handle) t
    WHERE
        r.blocking_session_id = 0
        AND r.session_id IN (SELECT DISTINCT blocking_session_id FROM sys.dm_exec_requests WHERE blocking_session_id != 0)
    
    UNION ALL

    SELECT
        r.session_id,
        r.blocking_session_id,
        s.login_name,
        s.host_name,
        s.program_name,
        r.command,
        t.text,
        bt.Level + 1
    FROM
        sys.dm_exec_requests r
    INNER JOIN
        sys.dm_exec_sessions s ON r.session_id = s.session_id
    OUTER APPLY
        sys.dm_exec_sql_text(r.sql_handle) t
    INNER JOIN BlockingTree bt ON r.blocking_session_id = bt.session_id
)
SELECT
    REPLICATE('    ', Level) + CAST(session_id AS NVARCHAR(10)) AS [Session Tree],
    session_id,
    blocking_session_id,
    login_name,
    host_name,
    program_name,
    command,
    sql_text
FROM
    BlockingTree
ORDER BY
    Level, session_id;

