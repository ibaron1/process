-- Parameters
DECLARE @schemaA NVARCHAR(128) = 'abc';
DECLARE @schemaB NVARCHAR(128) = 'dbo';
DECLARE @asof_dt DATETIME = NULL;
DECLARE @update_dt DATETIME = NULL;

-- Log Tables
IF OBJECT_ID('dbo.recon_log') IS NULL
CREATE TABLE dbo.recon_log (
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

IF OBJECT_ID('dbo.recon_summary') IS NULL
CREATE TABLE dbo.recon_summary (
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

delete dbo.recon_log; 
delete dbo.recon_summary;

-- Cursor setup
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
    DECLARE @key_columns NVARCHAR(MAX);
    DECLARE @column_list NVARCHAR(MAX);
    DECLARE @key_join NVARCHAR(MAX);
    DECLARE @key_isnullA NVARCHAR(MAX);
    DECLARE @key_isnullB NVARCHAR(MAX);
    DECLARE @col_name NVARCHAR(128);
    DECLARE @sql NVARCHAR(MAX) = '';

    -- Get unique key columns with t1 alias for use in mismatch key
    SELECT @key_columns = STRING_AGG('t1.' + QUOTENAME(c.name), ', ')
    FROM sys.indexes i
    JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
    JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
    WHERE i.object_id = @object_id AND i.is_unique = 1 AND i.type IN (1, 2);

    IF @key_columns IS NULL
    BEGIN
        PRINT 'Skipping ' + @table_name + ': No unique index found.';
        FETCH NEXT FROM table_cursor INTO @table_name;
        CONTINUE;
    END

    -- Generate key join and IS NULL conditions
    SELECT 
        @key_join = STRING_AGG('t1.' + QUOTENAME(c.name) + ' = t2.' + QUOTENAME(c.name), ' AND '),
        @key_isnullA = STRING_AGG('t2.' + QUOTENAME(c.name) + ' IS NULL', ' AND '),
        @key_isnullB = STRING_AGG('t1.' + QUOTENAME(c.name) + ' IS NULL', ' AND ')
    FROM sys.indexes i
    JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
    JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
    WHERE i.object_id = @object_id AND i.is_unique = 1 AND i.type IN (1, 2);

    -- Get columns to compare
    SELECT @column_list = STRING_AGG(QUOTENAME(c.name), ', ')
    FROM sys.columns c
    WHERE c.object_id = @object_id AND c.name NOT IN ('asof_dt', 'update_dt', 'revised_dt');

    -- Build WHERE filter
    DECLARE @filter NVARCHAR(MAX) = '';
    IF @asof_dt IS NOT NULL SET @filter = 'WHERE asof_dt = @asof_dt';
    IF @update_dt IS NOT NULL SET @filter = 'WHERE update_dt = @update_dt';
    IF @asof_dt IS NOT NULL AND @update_dt IS NOT NULL SET @filter = 'WHERE asof_dt = @asof_dt AND update_dt = @update_dt';

    SET @sql = '
    DECLARE @onlyA INT = 0, @onlyB INT = 0;

    SELECT * INTO #t1 FROM ' + QUOTENAME(@schemaA) + '.' + QUOTENAME(@table_name) + ' ' + @filter + ';
    SELECT * INTO #t2 FROM ' + QUOTENAME(@schemaB) + '.' + QUOTENAME(@table_name) + ' ' + @filter + ';

    -- Column mismatches
    ';

    DECLARE col_cursor CURSOR FOR
    SELECT name FROM sys.columns
    WHERE object_id = @object_id AND name NOT IN ('asof_dt', 'update_dt', 'revised_dt');

    OPEN col_cursor;
    FETCH NEXT FROM col_cursor INTO @col_name;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @sql += '
        INSERT INTO dbo.recon_log (table_name, mismatch_key, column_name, value_schemaA, value_schemaB, schemaA, schemaB)
        SELECT ''' + @table_name + ''',
               CONCAT_WS('':'', ' + @key_columns + '),
               ''' + @col_name + ''',
               CONVERT(NVARCHAR(MAX), t1.' + QUOTENAME(@col_name) + '),
               CONVERT(NVARCHAR(MAX), t2.' + QUOTENAME(@col_name) + '),
               ''' + @schemaA + ''', ''' + @schemaB + '''
        FROM #t1 t1
        JOIN #t2 t2 ON ' + @key_join + '
        WHERE ISNULL(CONVERT(NVARCHAR(MAX), t1.' + QUOTENAME(@col_name) + '), ''<NULL>'') <> ISNULL(CONVERT(NVARCHAR(MAX), t2.' + QUOTENAME(@col_name) + '), ''<NULL>'');
        ';
        FETCH NEXT FROM col_cursor INTO @col_name;
    END
    CLOSE col_cursor;
    DEALLOCATE col_cursor;

    -- Row existence mismatches
    SET @sql += '
    SELECT @onlyA = COUNT(*)
    FROM #t1 t1
    LEFT JOIN #t2 t2 ON ' + @key_join + '
    WHERE ' + @key_isnullA + ';

    SELECT @onlyB = COUNT(*)
    FROM #t2 t2
    LEFT JOIN #t1 t1 ON ' + @key_join + '
    WHERE ' + @key_isnullB + ';

    INSERT INTO dbo.recon_summary (
        table_name, total_rows_schemaA, total_rows_schemaB,
        matching_rows, column_mismatches, missing_in_schemaA, missing_in_schemaB,
        schemaA, schemaB
    )
    SELECT ''' + @table_name + ''',
           (SELECT COUNT(*) FROM #t1),
           (SELECT COUNT(*) FROM #t2),
           0,
           (SELECT COUNT(*) FROM dbo.recon_log WHERE table_name = ''' + @table_name + '''),
           @onlyB, @onlyA,
           ''' + @schemaA + ''', ''' + @schemaB + ''';

    DROP TABLE #t1; DROP TABLE #t2;
    ';

    EXEC sp_executesql @sql, N'@asof_dt DATETIME, @update_dt DATETIME', @asof_dt, @update_dt;

    FETCH NEXT FROM table_cursor INTO @table_name;
END

CLOSE table_cursor;
DEALLOCATE table_cursor;

--Recon detailed report
select * from dbo.recon_log; 
--Recon summary report
select * from dbo.recon_summary;