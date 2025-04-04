-- Query to get details of executed processes, including session_id, statement text, object name, query plan, tempdb usage, and more
SELECT
    ses.session_id,
    ses.login_name,
    ses.host_name,
    req.status AS request_status,
    req.command,
    t.text AS executed_sql_text,
    qp.query_plan,
    CASE
        WHEN req.statement_start_offset = 0 AND req.statement_end_offset = 0 THEN 'Ad-Hoc'
        ELSE 'Compiled'
    END AS statement_type,
    obj.name AS object_name,
    isnull(obj.type_desc, iif(not(req.statement_start_offset = 0 AND req.statement_end_offset = 0),'Parameterised query',null)) AS object_type,
    cast(space.internal_objects_alloc_page_count/128.0 as dec(24,2)) as tempdb_alloc_space_MB,
	cast(space.internal_objects_dealloc_page_count/128.0 as dec(24,2)) as tempdb_dealloc_space_MB,
	cast((space.internal_objects_alloc_page_count - space.internal_objects_dealloc_page_count)/128.0 as dec(24,2)) as used_tempdb_space,
    req.cpu_time AS cpu_time_ms,
    req.total_elapsed_time AS elapsed_time_ms,
    req.logical_reads, -- Logical reads
    req.reads,  -- Physical reads
	req.writes, -- Physical writes
	req.percent_complete,
	req.estimated_completion_time,
    -- Wait statistics (comma-separated list with wait time)
    STUFF((
        SELECT ',' + wait_stats.wait_type + ' (' + CAST(wait_stats.wait_time_ms AS VARCHAR) + ')'
        FROM sys.dm_exec_requests AS req_wait
        CROSS APPLY sys.dm_exec_session_wait_stats AS wait_stats
        WHERE req_wait.session_id = req.session_id
        FOR XML PATH('')), 1, 1, '') AS [wait_stat (ms)],
    -- Transaction state and blocking info
    CASE
        WHEN req.transaction_id IS NOT NULL THEN 'Yes'
        ELSE 'No'
    END AS is_transaction,
    CASE
        WHEN req.blocking_session_id <> 0 THEN 'Blocked by session ' + CAST(req.blocking_session_id AS VARCHAR)
        ELSE 'No blocking'
    END AS blocking_info
FROM
    sys.dm_exec_sessions AS ses
JOIN
    sys.dm_exec_requests AS req ON ses.session_id = req.session_id
OUTER APPLY
    sys.dm_exec_sql_text(req.sql_handle) AS t
OUTER APPLY
    sys.dm_exec_query_plan(req.plan_handle) AS qp
LEFT JOIN
    sys.objects AS obj ON req.plan_handle = obj.object_id
LEFT JOIN
    sys.procedures AS proc_alias ON obj.object_id = proc_alias.object_id
LEFT JOIN
    sys.dm_db_session_space_usage AS space ON ses.session_id = space.session_id
WHERE
    ses.session_id > 50 -- Exclude system sessions
    AND req.status = 'running'; -- Filter only running requests
