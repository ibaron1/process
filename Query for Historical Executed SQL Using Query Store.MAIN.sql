/*
To get historical information about executed SQL statements in SQL Server, you would generally need to leverage the SQL Server Extended Events or SQL Server Profiler to capture the queries, as system views and DMVs like sys.dm_exec_requests only provide information about currently executing queries.

For historical information, there are two main ways:

Using Extended Events: You can create an Extended Event session to capture queries and then query the captured data later.

Using the Query Store: If the Query Store feature is enabled, SQL Server keeps a history of executed queries.

I’ll show you how to get historical SQL execution data using the Query Store, which stores historical query performance data.

Query for Historical Executed SQL Using Query Store
If Query Store is enabled on your database, you can query the historical execution information from the sys.query_store_query and sys.query_store_runtime_stats views.

Here’s a query to get the historical SQL execution details, including session IDs, statement text, query plan, CPU time, elapsed time, logical reads, and physical reads.

SQL Query to Get Historical Executed SQL from Query Store
*/
use AdventureWorks2022;

-- Query to get historical executed SQL information from Query Store
-- Query to get historical executed SQL information from Query Store
SELECT
    qsq.query_id,
    qsq.query_text_id,
    qt.query_sql_text AS executed_sql_text,
	qsq.query_parameterization_type,
    cast(qrp.query_plan as xml) as query_plan,
	qrs.avg_duration AS avg_elapsed_time_ms	,
	qrs.min_duration AS min_elapsed_time_ms	,
	qrs.max_duration AS max_elapsed_time_ms	,
	qrs.avg_cpu_time,
	qrs.last_cpu_time,
	qrs.min_cpu_time,
	qrs.max_cpu_time,
	qrs.min_logical_io_reads,
	qrs.max_logical_io_reads, 
	qrs.avg_logical_io_reads,
	qrs.avg_logical_io_writes,	
	qrs.last_logical_io_writes,	
	qrs.min_logical_io_writes,	
	qrs.max_logical_io_writes,
    qrs.avg_physical_io_reads,
	qrs.last_physical_io_reads,
	qrs.min_physical_io_reads,
	qrs.max_physical_io_reads,
	qrs.avg_query_max_used_memory,
	qrs.last_query_max_used_memory,
	qrs.min_query_max_used_memory,
	qrs.max_query_max_used_memory,
	qrs.first_execution_time,
	qrs.last_execution_time,
    qrs.count_executions
FROM
   sys.query_store_runtime_stats as qrs
JOIN 
    sys.query_store_plan AS qsp
    ON qrs.plan_id = qsp.plan_id
JOIN 
    sys.query_store_query AS qsq
    ON qsp.query_id = qsq.query_id
JOIN
    sys.query_store_query_text AS qt ON qsq.query_text_id = qt.query_text_id
JOIN
    sys.query_store_plan AS qrp ON qrs.plan_id = qrp.plan_id 
WHERE
    qrs.count_executions > 0
ORDER BY
    qrs.count_executions DESC; -- order by execution count or any other column

/*
Explanation of Columns:
query_id: The unique identifier for the query.

query_text_id: The identifier for the query text in the sys.query_store_query_text table.

executed_sql_text: The SQL text of the query that was executed.

query_plan: The query execution plan for the query.

cpu_time_ms: Total CPU time for the query execution.

elapsed_time_ms: Total elapsed time for the query execution.

logical_reads: The number of logical reads (buffer cache reads) for the query execution.

physical_reads: The number of physical reads (disk reads) for the query execution.

write_operations: The number of write operations performed by the query.

execution_count: The number of times the query has been executed.

avg_cpu_time_ms: The average CPU time for the query execution.

avg_duration_ms: The average duration of the query execution.

max_cpu_time_ms: The maximum CPU time for a single execution of the query.

max_duration_ms: The maximum duration for a single execution of the query.

statement_type: Type of the statement (could be compiled or ad-hoc).

object_type: Type of object (e.g., procedure, function, etc.).

Notes:
Query Store: This feature must be enabled in the database for this query to work. If Query Store is not enabled, you can enable it using:

sql
Copy
ALTER DATABASE [YourDatabase] SET QUERY_STORE = ON;
Execution History: The Query Store retains execution history by default, but it may be affected by the size of the Query Store and retention policies. If you're looking for deep historical data, consider adjusting the Query Store configuration settings (e.g., retention period, data size).

Plan Availability: The query plan is available for queries stored in the Query Store, but if a query execution plan is evicted or hasn't been captured, it may not be available.

Temporal Data: For more granular historical data (e.g., exact time of execution), you'll need to query the relevant time frames from the sys.query_store_runtime_stats and sys.query_store_runtime_stats_interval views.

Example of Creating a Query Store Session
If you don’t have Query Store enabled, you can also create an Extended Events session that captures query execution history, but that's a more advanced setup that would require creating an event session, which may be complex for capturing a lot of data. However, Query Store is the easiest and most effective way to gather historical SQL execution data in SQL Server.
*/