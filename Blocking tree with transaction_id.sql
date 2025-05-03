SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET IMPLICIT_TRANSACTIONS OFF;
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
        r.wait_resource
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
    bt.database_name,
    @@SERVERNAME AS instance_name,
    bt.wait_type,
    bt.wait_time,
    bt.wait_resource,
    CASE 
        WHEN bt.session_id = bt.blocking_session_id THEN LEFT(ISNULL(st.text, 'No SQL Text Available'), 4000) 
        ELSE NULL 
    END AS blocking_sql_text,
    CASE 
        WHEN bt.session_id != bt.blocking_session_id THEN LEFT(ISNULL(st2.text, 'No SQL Text Available'), 4000)
        ELSE NULL
    END AS sql_text,
    qp.query_plan AS execution_plan_xml,
    tr.transaction_id,
	case txn.database_transaction_type 
		when 1 then 'Read/write'
		when 2 then 'Read-only transaction'
		when 3 then 'System transaction'
		else NULL end as database_transaction_type,
    case txn.database_transaction_state
		when 1 then 'transaction has not been initialized'
		when 3 then 'transaction has been initialized but has not generated any log records'
		when 4 then 'The transaction has generated log records'
		when 5 then 'transaction has been prepared'
		when 10 then 'transaction has been committed'
		when 11 then 'transaction has been rolled back'
		when 12 then 'transaction is being committed. (The log record is being generated, but has not been materialized or persisted)'
	end as database_transaction_state,
    txn.database_transaction_begin_time,
    DATEDIFF(SECOND, txn.database_transaction_begin_time, GETDATE()) AS transaction_duration_seconds
FROM Tree t
JOIN BlockingTree bt ON t.session_id = bt.session_id
OUTER APPLY sys.dm_exec_sql_text(bt.sql_handle) AS st -- For the blocker session
OUTER APPLY sys.dm_exec_sql_text(bt.sql_handle) AS st2 -- For the blocked session (can be different)
OUTER APPLY sys.dm_exec_query_plan(bt.plan_handle) AS qp
LEFT JOIN sys.dm_tran_session_transactions tr ON bt.session_id = tr.session_id
LEFT JOIN sys.dm_tran_database_transactions txn ON tr.transaction_id = txn.transaction_id
ORDER BY t.Level, t.BlockChain;
