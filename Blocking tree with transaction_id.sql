WITH Requests AS (
    SELECT 
        r.session_id,
        r.blocking_session_id,
        r.wait_type,
        r.wait_time,
        r.sql_handle,
        r.wait_resource,
        r.command,
        r.start_time,
        r.database_id
    FROM sys.dm_exec_requests r
),
BlockingTree AS (
    SELECT 
        s.session_id,
        r.blocking_session_id,
        r.wait_type,
        r.wait_time,
        s.login_name,
        s.original_login_name,
        s.host_name,
        s.program_name,
        s.status,
        r.command,
        r.start_time,
        DB_NAME(r.database_id) AS database_name,
        r.sql_handle,
        r.wait_resource
    FROM sys.dm_exec_sessions s
    LEFT JOIN Requests r ON s.session_id = r.session_id
    WHERE s.session_id IN (
        SELECT session_id FROM Requests WHERE blocking_session_id != 0
        UNION
        SELECT blocking_session_id FROM Requests WHERE blocking_session_id != 0
    )
),
Tree AS (
    SELECT 
        bt.session_id,
        bt.blocking_session_id,
        CAST(bt.session_id AS VARCHAR(MAX)) AS BlockChain,
        0 AS Level
    FROM BlockingTree bt
    WHERE bt.blocking_session_id IS NULL OR bt.blocking_session_id NOT IN (SELECT session_id FROM BlockingTree)

    UNION ALL

    SELECT 
        bt.session_id,
        bt.blocking_session_id,
        CAST(t.BlockChain + ' -> ' + CAST(bt.session_id AS VARCHAR(10)) AS VARCHAR(MAX)),
        t.Level + 1
    FROM BlockingTree bt
    JOIN Tree t ON bt.blocking_session_id = t.session_id
)
SELECT
    REPLICATE('   ', t.Level) + 
        CASE WHEN t.Level = 0 THEN '+ ' ELSE '|_ ' END +
        'SPID ' + CAST(bt.session_id AS VARCHAR) + 
        ISNULL(' (blocking SPID ' + CAST(bt.blocking_session_id AS VARCHAR) + ')', '') AS BlockingTreeView,
    bt.login_name,
    bt.original_login_name,
    bt.host_name,
    bt.program_name,
    bt.status,
    bt.command,
    bt.database_name,
    bt.wait_type,
    bt.wait_time,
    bt.wait_resource,
    LEFT(st.text, 200) AS blocking_sql_text,
    tr.transaction_id -- Show the transaction ID (if available) for blocking sessions
FROM Tree t
JOIN BlockingTree bt ON t.session_id = bt.session_id
OUTER APPLY sys.dm_exec_sql_text(bt.sql_handle) AS st
LEFT JOIN sys.dm_tran_session_transactions tr ON bt.session_id = tr.session_id -- Correct join here
ORDER BY t.Level, t.BlockChain;
