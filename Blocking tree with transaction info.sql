WITH Requests AS (
    SELECT 
        r.session_id,
        r.blocking_session_id,
        r.wait_type,
        r.wait_time,
        r.sql_handle,
        r.plan_handle,
        r.wait_resource,
        r.command,
        r.start_time,
        r.database_id
    FROM sys.dm_exec_requests r
	where (r.blocking_session_id IS NULL OR r.blocking_session_id != 0)
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
        DB_NAME(ISNULL(r.database_id, s.database_id)) AS database_name,
        r.sql_handle,
        r.plan_handle,
        r.wait_resource,
        s.transaction_isolation_level -- Get the isolation level from sys.dm_exec_sessions
    FROM sys.dm_exec_sessions s
    LEFT JOIN Requests r ON s.session_id = r.session_id
    WHERE 
        s.is_user_process = 1
        AND s.session_id != 0
        AND s.status != 'sleeping'
),
Tree AS (
    SELECT 
        bt.session_id,
        bt.blocking_session_id,
        CAST(bt.session_id AS VARCHAR(MAX)) AS BlockChain,
        0 AS Level
    FROM BlockingTree bt
    WHERE bt.blocking_session_id IS NULL 
       OR bt.blocking_session_id NOT IN (SELECT session_id FROM BlockingTree)

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
        CASE WHEN bt.blocking_session_id IS NOT NULL THEN ' (blocking SPID ' + CAST(bt.blocking_session_id AS VARCHAR) + ')' ELSE '' END AS BlockingTreeView,
    bt.login_name,
    bt.original_login_name,
    bt.host_name,
    bt.program_name,
    bt.status,
    bt.command,
    CASE 
        WHEN bt.transaction_isolation_level = 1 THEN 'Read Uncommitted'
        WHEN bt.transaction_isolation_level = 2 THEN 'Read Committed'
        WHEN bt.transaction_isolation_level = 3 THEN 'Repeatable Read'
        WHEN bt.transaction_isolation_level = 4 THEN 'Serializable'
        WHEN bt.transaction_isolation_level = 5 THEN 'Snapshot'
        ELSE 'Unknown'
    END AS session_transaction_isolation_level,
    bt.database_name,
    @@SERVERNAME AS instance_name,
    bt.wait_type,
    bt.wait_time,
    bt.wait_resource,
    bt.sql_handle, -- Include sql_handle for debugging
    -- Fetch SQL Text for the Blocking Session from sys.dm_exec_requests
    CASE 
        WHEN bt.session_id = bt.blocking_session_id THEN 
            LEFT(ISNULL(st.text, 'No SQL Text Available'), 4000)  -- For the blocker session
        ELSE NULL 
    END AS blocking_sql_text,
    -- Fetch SQL Text for the Blocked Session
    CASE 
        WHEN bt.session_id != bt.blocking_session_id THEN 
            LEFT(ISNULL(st2.text, 'No SQL Text Available'), 4000)  -- For the blocked session
        ELSE NULL
    END AS sql_text,
    qp.query_plan AS execution_plan_xml,
    tr.transaction_id,
    CASE txn.database_transaction_type 
        WHEN 1 THEN 'Read/write'
        WHEN 2 THEN 'Read-only transaction'
        WHEN 3 THEN 'System transaction'
        ELSE NULL 
    END AS database_transaction_type,
    CASE txn.database_transaction_state
        WHEN 1 THEN 'transaction has not been initialized'
        WHEN 3 THEN 'transaction has been initialized but has not generated any log records'
        WHEN 4 THEN 'The transaction has generated log records'
        WHEN 5 THEN 'transaction has been prepared'
        WHEN 10 THEN 'transaction has been committed'
        WHEN 11 THEN 'transaction has been rolled back'
        WHEN 12 THEN 'transaction is being committed. (The log record is being generated, but has not been materialized or persisted)'
    END AS database_transaction_state,
    txn.database_transaction_begin_time,
    CASE 
        WHEN txn.database_transaction_begin_time IS NOT NULL 
        THEN DATEDIFF(SECOND, txn.database_transaction_begin_time, GETDATE())
        ELSE NULL
    END AS transaction_duration_seconds
FROM Tree t
JOIN BlockingTree bt ON t.session_id = bt.session_id
-- Join sys.dm_exec_requests to get SQL Text for the blocking session
OUTER APPLY sys.dm_exec_sql_text(bt.sql_handle) AS st -- For the blocker session
OUTER APPLY sys.dm_exec_sql_text(bt.sql_handle) AS st2 -- For the blocked session (can be different)
OUTER APPLY sys.dm_exec_query_plan(bt.plan_handle) AS qp
LEFT JOIN sys.dm_tran_session_transactions tr ON bt.session_id = tr.session_id
LEFT JOIN sys.dm_tran_database_transactions txn ON tr.transaction_id = txn.transaction_id
ORDER BY t.Level, t.BlockChain;
