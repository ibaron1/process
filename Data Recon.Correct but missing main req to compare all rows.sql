--add when @asof_dt  = NULL and @update_dt = null --> it is tghe same as for update_dt but for all rows
-- Parameters
DECLARE @schemaA NVARCHAR(128) = 'iborop';
DECLARE @schemaB NVARCHAR(128) = 'dbo';
DECLARE @asof_dt DATETIME = --NULL 
getdate();
 DECLARE @update_dt DATETIME = --NULL
 '2025-06-01 19:51:30.413';

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

-- Logging Tables
DROP TABLE IF EXISTS ##recon_log;
CREATE TABLE ##recon_log (
    log_id INT IDENTITY(1,1) PRIMARY KEY,
    table_name NVARCHAR(128),
    mismatch_key NVARCHAR(500),
    column_name NVARCHAR(128),
    value_schemaA NVARCHAR(MAX),
    value_schemaB NVARCHAR(MAX),
    schemaA NVARCHAR(128),
    schemaB NVARCHAR(128),
    log_dt DATETIME DEFAULT GETDATE()
);

DROP TABLE IF EXISTS ##recon_summary;
CREATE TABLE ##recon_summary (
    summary_id INT IDENTITY(1,1) PRIMARY KEY,
    table_name NVARCHAR(128),
    total_rows_schemaA INT,
    total_rows_schemaB INT,
    matching_rows INT,
    column_mismatches INT,
    missing_in_schemaA INT,
    missing_in_schemaB INT,
    schemaA NVARCHAR(128),
    schemaB NVARCHAR(128),
    log_dt DATETIME DEFAULT GETDATE()
);

DELETE FROM ##recon_log;
DELETE FROM ##recon_summary;

-- Cursor to loop over tables
DECLARE @table_name NVARCHAR(128);
DECLARE table_cursor CURSOR FOR
SELECT t.name
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = @schemaA
  AND EXISTS (
      SELECT 1 FROM sys.tables t2
      JOIN sys.schemas s2 ON t2.schema_id = s2.schema_id
      WHERE t2.name = t.name AND s2.name = @schemaB
  );

OPEN table_cursor;
FETCH NEXT FROM table_cursor INTO @table_name;

WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @object_id INT = OBJECT_ID(QUOTENAME(@schemaA) + '.' + QUOTENAME(@table_name));
    DECLARE @sql NVARCHAR(MAX) = '';
    DECLARE @key_columns NVARCHAR(MAX) = '';
    DECLARE @key_join NVARCHAR(MAX) = '';
    DECLARE @key_isnullA NVARCHAR(MAX) = '';
    DECLARE @key_isnullB NVARCHAR(MAX) = '';
    DECLARE @key_concat_expr NVARCHAR(MAX) = '';
    DECLARE @nonkey_columns_list NVARCHAR(MAX) = '';
    DECLARE @key_count INT;
	DECLARE @key_concat_mismatch NVARCHAR(MAX);

    -- Unique key detection
    SELECT @key_count = COUNT(1)
    FROM sys.indexes i
    JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
    WHERE i.object_id = @object_id AND i.is_unique = 1 AND i.type IN (1, 2);

    IF @key_count = 0
    BEGIN
        PRINT 'Skipping ' + @table_name + ': No unique key found.';
        FETCH NEXT FROM table_cursor INTO @table_name;
        CONTINUE;
    END

    -- Build key join logic
    SELECT 
        @key_columns = STRING_AGG(QUOTENAME(c.name), ', '),
        @key_join = STRING_AGG('t1.' + QUOTENAME(c.name) + ' = t2.' + QUOTENAME(c.name), ' AND '),
        @key_isnullA = STRING_AGG('t2.' + QUOTENAME(c.name) + ' IS NULL', ' AND '),
        @key_isnullB = STRING_AGG('t1.' + QUOTENAME(c.name) + ' IS NULL', ' AND ')
    FROM sys.indexes i
    JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
    JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
    WHERE i.object_id = @object_id AND i.is_unique = 1 AND i.type IN (1, 2);


	IF @update_dt IS NOT NULL
    BEGIN
    -- Concatenate key values for mismatch_key
    IF @key_count = 1
    SELECT @key_concat_mismatch = 'CONVERT(NVARCHAR(100), t1.' + QUOTENAME(c.name) + ')'
    FROM sys.indexes i
    JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
    JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
    WHERE i.object_id = @object_id AND i.is_unique = 1 AND i.type IN (1, 2);
ELSE
    SELECT @key_concat_mismatch = 'CONCAT_WS('':'', ' + STRING_AGG('CONVERT(NVARCHAR(100), t1.' + QUOTENAME(c.name) + ')', ', ') + ')'
    FROM sys.indexes i
    JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
    JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
    WHERE i.object_id = @object_id AND i.is_unique = 1 AND i.type IN (1, 2);

-- Compose key columns list for select and join
DECLARE @key_columns_list NVARCHAR(MAX);

SELECT @key_columns_list = STRING_AGG(QUOTENAME(c.name), ', ')
FROM sys.indexes i
JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE i.object_id = @object_id AND i.is_unique = 1 AND i.type IN (1, 2);

-- Compose join condition on keys
DECLARE @key_join_condition NVARCHAR(MAX);

SELECT @key_join_condition = STRING_AGG('t1.' + QUOTENAME(c.name) + ' = t2.' + QUOTENAME(c.name), ' AND ')
FROM sys.indexes i
JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE i.object_id = @object_id AND i.is_unique = 1 AND i.type IN (1, 2);

-- Compose key columns list for join on unpivoted tables (u1 and u2)
DECLARE @key_columns_for_join NVARCHAR(MAX);

SELECT @key_columns_for_join = STRING_AGG('u1.' + QUOTENAME(c.name) + ' = u2.' + QUOTENAME(c.name), ' AND ')
FROM sys.indexes i
JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE i.object_id = @object_id AND i.is_unique = 1 AND i.type IN (1, 2);

-- Build the dynamic SQL for update_dt scenario:
SET @sql += '
    SELECT * INTO #u1 FROM ' + QUOTENAME(@schemaA) + '.' + QUOTENAME(@table_name) + ' WHERE update_dt = @update_dt;
    SELECT * INTO #u2 FROM ' + QUOTENAME(@schemaB) + '.' + QUOTENAME(@table_name) + ' WHERE update_dt = @update_dt;

    WITH u1_unpivoted AS (
        SELECT
            ''' + @table_name + ''' AS table_name,
            ' + @key_concat_mismatch + ' AS mismatch_key,
            ' + @key_columns_list + ',
            col AS column_name,
            val AS value_schemaA
        FROM (
            SELECT ' + @key_columns_list + ', ' + @nonkey_columns_list + '
            FROM #u1
        ) src
        UNPIVOT (val FOR col IN (' + @nonkey_columns_list + ')) AS unpvt
    ),
    u2_unpivoted AS (
        SELECT ' + @key_columns_list + ',
            col AS column_name,
            val AS value_schemaB
        FROM (
            SELECT ' + @key_columns_list + ', ' + @nonkey_columns_list + '
            FROM #u2
        ) src
        UNPIVOT (val FOR col IN (' + @nonkey_columns_list + ')) AS unpvt
    ),
    mismatches AS (
        SELECT
            u1.table_name,
            u1.mismatch_key,
            u1.column_name,
            ISNULL(u1.value_schemaA, ''<NULL>'') AS value_schemaA,
            ISNULL(u2.value_schemaB, ''<NULL>'') AS value_schemaB
        FROM u1_unpivoted u1
        FULL OUTER JOIN u2_unpivoted u2
            ON ' + @key_columns_for_join + ' AND u1.column_name = u2.column_name
        WHERE ISNULL(u1.value_schemaA, ''<NULL>'') <> ISNULL(u2.value_schemaB, ''<NULL>'')
    )
    INSERT INTO ##recon_log (table_name, mismatch_key, column_name, value_schemaA, value_schemaB, schemaA, schemaB)
    SELECT
        table_name, mismatch_key, column_name, value_schemaA, value_schemaB, ''' + @schemaA + ''', ''' + @schemaB + '''
    FROM mismatches;

    -- Cleanup temp tables
    DROP TABLE #u1;
    DROP TABLE #u2;
';

    END

    -- Cleanup
    SET @sql += '
        IF OBJECT_ID(''tempdb..#t1'') IS NOT NULL DROP TABLE #t1;
        IF OBJECT_ID(''tempdb..#t2'') IS NOT NULL DROP TABLE #t2;
        IF OBJECT_ID(''tempdb..#u1'') IS NOT NULL DROP TABLE #u1;
        IF OBJECT_ID(''tempdb..#u2'') IS NOT NULL DROP TABLE #u2;
    ';

print @sql --dbg

	EXEC sp_executesql @sql, N'@asof_dt DATETIME, @update_dt DATETIME', @asof_dt, @update_dt;

    FETCH NEXT FROM table_cursor INTO @table_name;
END

CLOSE table_cursor;
DEALLOCATE table_cursor;

-- Final result
SELECT * FROM ##recon_log;
SELECT * FROM ##recon_summary;
