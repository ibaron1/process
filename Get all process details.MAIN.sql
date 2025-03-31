WITH WaitStats AS (
    SELECT
        req.session_id,
        STRING_AGG(CAST(wait_stats.wait_type + ' (' + CAST(wait_stats.wait_time_ms AS VARCHAR) + ')' AS VARCHAR(MAX)), ', ') 
            WITHIN GROUP (ORDER BY wait_stats.wait_time_ms DESC) AS [wait_stat (ms)]
    FROM
        sys.dm_exec_requests AS req
    CROSS APPLY
        sys.dm_exec_session_wait_stats AS wait_stats
    GROUP BY
        req.session_id
)
SELECT
    @@servername as [SQL Server Instance],
	DB_NAME(req.database_id) as [Database],
	ses.session_id,
	req.request_id, --unique in the context of the session
    req.user_id,	--user id who submitted the request
    ses.host_name,
    req.status AS request_status,
	req.start_time, --
    req.command,
	req.nest_level, --current nesting level of code that is executing on the request
	CAST(req.granted_query_memory/128.0 AS DEC(34,2)) as granted_query_memory_mb, --number of pages allocated to the execution of a query on the request
    req.row_count, --number of rows that have been returned to the client by this request
	t.text AS executed_sql_text,
    qp.query_plan,
    IIF(cp.cacheobjtype = 'Adhoc', 'Ad-Hoc', 'Compiled') AS statement_type,
	CASE WHEN 
			obj.name IS NULL
			AND t.text LIKE '%@%'  -- Look for any parameter (e.g., @ObjectType, @ParameterName) in the SQL text
			AND cp.cacheobjtype = 'Compiled Plan'  -- Ensure that we're looking at compiled query plans
		 THEN
			'Yes'
	END AS is_parameterized_query,
    obj.name AS object_name,
    obj.type_desc AS object_type,
	req.parallel_worker_count,
    CAST(space.internal_objects_alloc_page_count / 128.0 AS DECIMAL(24, 2)) AS tempdb_alloc_space_MB,
    CAST(space.internal_objects_dealloc_page_count / 128.0 AS DECIMAL(24, 2)) AS tempdb_dealloc_space_MB,
    CAST((space.internal_objects_alloc_page_count - space.internal_objects_dealloc_page_count) / 128.0 AS DECIMAL(24, 2)) AS used_tempdb_space,
    req.cpu_time AS cpu_time_ms,
    req.total_elapsed_time AS elapsed_time_ms,
    req.logical_reads, -- Logical reads
    req.reads,  -- Physical reads
    req.writes, -- Physical writes
    req.percent_complete,
    req.estimated_completion_time,
    -- Wait statistics (comma-separated list with wait time)
    ws.[wait_stat (ms)],
    -- Transaction state and blocking info
	CASE req.transaction_isolation_level
		WHEN 0 THEN 'Unspecified'
		WHEN 1 THEN 'ReadUncommitted'
		WHEN 2 THEN 'ReadCommitted'
		WHEN 3 THEN 'Repeatable'
		WHEN 4 THEN 'Serializable'
		WHEN 5 THEN 'Snapshot'
	END AS transaction_isolation_level,
	req.lock_timeout,
	req.deadlock_priority,
    IIF(req.transaction_id IS NOT NULL, 'Yes', 'No') AS is_transaction,
    IIF(isnull(req.blocking_session_id, 0) <> 0, CONCAT('Blocked by session ', 
			CASE req.blocking_session_id 
				WHEN -2 THEN 'The blocking resource is owned by an orphaned distributed transaction'
				WHEN -3 THEN 'The blocking resource is owned by a deferred recovery transaction'
				WHEN -4 THEN 'session_id of the blocking latch owner couldn''t be determined at this time because of internal latch state transitions'
				WHEN -5 THEN 'session_id of the blocking latch owner couldn''t be determined because it isn''t tracked for this latch type (for example, for an SH latch)'
				ELSE req.blocking_session_id
			END), 'No blocking') AS blocking_info,
    req.wait_type,
    req.wait_time,
    req.wait_resource
FROM
    sys.dm_exec_sessions AS ses
JOIN
    sys.dm_exec_requests AS req ON ses.session_id = req.session_id
OUTER APPLY
    (SELECT TOP 1 * 
     FROM sys.dm_exec_cached_plans cp
     WHERE cp.plan_handle = req.plan_handle) AS cp
OUTER APPLY
    sys.dm_exec_sql_text(req.sql_handle) AS t
OUTER APPLY
    sys.dm_exec_query_plan(req.plan_handle) AS qp
LEFT JOIN
    sys.objects AS obj ON req.plan_handle = obj.object_id
LEFT JOIN
    sys.dm_db_session_space_usage AS space ON ses.session_id = space.session_id
LEFT JOIN
    WaitStats ws ON ses.session_id = ws.session_id  -- Join the aggregated wait stats
WHERE
    ses.session_id > 50  -- Exclude system sessions
    AND req.status = 'running';  -- Filter only running requests
