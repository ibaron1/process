-- Blocking Tree in SQL Server
SELECT
    session_id AS [SPID],
    blocking_session_id AS [Blocked By],
    wait_type,
    wait_time,
    wait_resource,
    DB_NAME(database_id) AS [Database],
    status,
    login_name,
    host_name,
    program_name,
    last_request_start_time,
    last_request_end_time,
    text AS [SQL Text]
FROM
    sys.dm_exec_requests r
OUTER APPLY
    sys.dm_exec_sql_text(r.sql_handle) t
WHERE
    session_id > 50 -- system sessions are usually below 50
ORDER BY
    blocking_session_id, session_id;

-- Blocking Tree (more structured, tree-like view)
WITH BlockingTree AS (
    SELECT
        session_id,
        blocking_session_id,
        0 AS Level
    FROM
        sys.dm_exec_requests
    WHERE
        blocking_session_id = 0

    UNION ALL

    SELECT
        r.session_id,
        r.blocking_session_id,
        bt.Level + 1
    FROM
        sys.dm_exec_requests r
        INNER JOIN BlockingTree bt ON r.blocking_session_id = bt.session_id
)
SELECT
    REPLICATE('    ', Level) + CAST(session_id AS NVARCHAR(10)) AS BlockingHierarchy,
    session_id,
    blocking_session_id,
    Level
FROM
    BlockingTree
ORDER BY
    Level, session_id;
