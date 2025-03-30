-- Query to get details of executed processes including session_id, statement text, and query plan
/*
Key Columns:
session_id: The ID of the session that executed the process.
login_name: The login name associated with the session.
host_name: The name of the host computer from which the session was initiated.
request_status: The status of the request (e.g., running, suspended).
command: The type of SQL command being executed (e.g., SELECT, INSERT, UPDATE).
executed_sql_text: The SQL text of the executed statement.
statement_type: Identifies whether the statement was ad-hoc or compiled (e.g., stored procedure).
query_plan: The execution plan for the query in XML format.
The WHERE ses.session_id > 50 condition filters out system sessions (system sessions typically have a session_id ≤ 50).

The req.status = 'running' filter only includes the currently executing requests. 
Remove/modify this filter to retrieve past or idle sessions as well.

Key Notes:
sys.dm_exec_requests: This view contains an sql_handle, but not a plan_handle. Therefore, we are using the sql_handle to get the executed SQL text using sys.dm_exec_sql_text(sql_handle).
sys.dm_exec_query_plan: 
This function takes a plan_handle as input to fetch the query execution plan. 
The plan_handle is part of the sys.dm_exec_sessions and sys.dm_exec_requests, but since we are pulling the sql_handle, 
the query plan can be extracted by utilizing the sys.dm_exec_query_plan.

Please note:
The OUTER APPLY with sys.dm_exec_query_plan ensures that you can get the execution plan (if available). If the query does not have an execution plan, it will return NULL.
*/

-- Query to get details of executed processes including session_id, statement text, and query plan
-- Query to get details of executed processes, including session_id, statement text, object name, query plan, and tempdb usage
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
	cast((space.internal_objects_alloc_page_count - space.internal_objects_dealloc_page_count)/128.0 as dec(24,2)) as used_tempdb_space

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
    sys.procedures AS [proc] ON obj.object_id = [proc].object_id
LEFT JOIN
    sys.dm_db_session_space_usage AS space ON ses.session_id = space.session_id
WHERE
    ses.session_id > 50 -- Exclude system sessions
    AND req.status = 'running'; -- Filter only running requests

