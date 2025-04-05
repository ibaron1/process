WITH WaitResourceInfo AS (
    SELECT 
        @@servername as [SQL Server instance],
		DB_NAME(r.database_id) as [database],
		r.session_id,
        r.wait_type,
        r.wait_time as wait_time_ms,
        r.wait_resource,
        r.blocking_session_id,
        r.status,
        r.command,
        r.sql_handle,
        r.start_time,
        r.cpu_time,
        r.total_elapsed_time,
        CASE
            -- Wait categories based on wait type
            WHEN r.wait_type LIKE 'LCK%' THEN 'Lock Wait'
            WHEN r.wait_type LIKE 'PAGEIOLATCH%' THEN 'Page I/O Wait'
            WHEN r.wait_type LIKE 'IO_COMPLETION' THEN 'I/O Completion'
            WHEN r.wait_type LIKE 'LCX%' THEN 'Latch Wait'
            WHEN r.wait_type LIKE 'ASYNC%' THEN 'Async I/O Wait'
            WHEN r.wait_type LIKE 'NETWORK%' THEN 'Network Wait'
            WHEN r.wait_type LIKE 'CXPACKET%' THEN 'Parallel Query Wait'
            WHEN r.wait_type LIKE 'RESOURCE%' THEN 'Resource Wait'
            WHEN r.wait_type LIKE 'SLEEP%' THEN 'Sleep Wait'
            WHEN r.wait_type LIKE 'PREEMPTIVE%' THEN 'Preemptive Wait'
            WHEN r.wait_type LIKE 'SPINLOCK%' THEN 'Spinlock Contention'
            ELSE 'Other Wait Type'
        END AS WaitCategory
    FROM 
        sys.dm_exec_requests r
    WHERE 
        r.wait_type <> 'WAITFOR'
        AND r.wait_resource IS NOT NULL
)

SELECT 
    w.[SQL Server instance],
	w.[database],
	w.session_id,
    w.wait_type,
    w.wait_time_ms,
    w.wait_resource,
    w.blocking_session_id,
    w.status,
    w.command,
    w.sql_handle,
    w.start_time,
    w.cpu_time,
    w.total_elapsed_time,
    w.WaitCategory,
    
    -- Decoding lock-related waits
    CASE
        WHEN w.wait_type LIKE 'LCK%' THEN 
            (SELECT TOP 1 
                l.resource_type
            FROM sys.dm_tran_locks l
            WHERE l.request_session_id = w.session_id
            FOR XML PATH(''))  -- Convert to a single string
        
        -- Decoding page I/O waits
        WHEN w.wait_type LIKE 'PAGEIOLATCH%' THEN 
            (SELECT TOP 1 
                f.physical_name
            FROM sys.database_files f
            --WHERE f.database_id = DB_ID()
            FOR XML PATH(''))  -- Convert to a single string
        
        -- Decoding I/O completion waits
        WHEN w.wait_type LIKE 'IO_COMPLETION' THEN 
            (SELECT TOP 1 
                f.physical_name
            FROM sys.database_files f
            --WHERE f.database_id = DB_ID()
            FOR XML PATH(''))  -- Convert to a single string

        -- Decoding latch-related waits
        WHEN w.wait_type LIKE 'LCX%' THEN 
            'Latch-related wait, specific resource is internal'

        -- Handling async I/O waits (such as async network I/O or writes)
        WHEN w.wait_type LIKE 'ASYNC%' THEN 
            'Asynchronous I/O wait'
        
        -- Decoding network waits (e.g., client or remote network waits)
        WHEN w.wait_type LIKE 'NETWORK%' THEN 
            'Network-related wait, usually indicates network latency or issues'
        
        -- Decoding parallel query waits
        WHEN w.wait_type LIKE 'CXPACKET%' THEN 
            'Parallel query wait, indicates CPU or data skew issues during parallel execution'

        -- Decoding resource waits (e.g., resource pool contention)
        WHEN w.wait_type LIKE 'RESOURCE%' THEN 
            'Resource contention, typically involving CPU or memory'
        
        -- Handling sleep or waiting on external signals
        WHEN w.wait_type LIKE 'SLEEP%' THEN 
            'Sleeping (Idle wait), session is in a waiting state but not actively waiting for a resource'
        
        -- Handling preemptive waits (indicates OS-level operations)
        WHEN w.wait_type LIKE 'PREEMPTIVE%' THEN 
            'Preemptive Wait, indicates the session is waiting for an OS resource'
        
        -- Spinlock contention waits (high concurrency and internal resource waits)
        WHEN w.wait_type LIKE 'SPINLOCK%' THEN 
            'Spinlock contention, often indicates contention for internal resources in SQL Server'

        ELSE 
            'Other wait type'
    END AS WaitResourceDetails
FROM 
    WaitResourceInfo w;
