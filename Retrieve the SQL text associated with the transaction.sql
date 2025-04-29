SELECT 
    r.transaction_id,
    r.session_id,
    t.text AS sql_text
FROM 
    sys.dm_exec_requests r
CROSS APPLY 
    sys.dm_exec_sql_text(r.sql_handle) t
WHERE 
    r.transaction_id = <YourTransactionID>;
