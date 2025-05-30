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

DELETE FROM dbo.recon_log;
DELETE FROM dbo.recon_summary;

-- Cursor to process all tables
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
    DECLARE @nonkey_columns NVARCHAR(MAX) = '';
    DECLARE @key_count INT;
    DECLARE @select_diff_cols NVARCHAR(MAX) = '';
    DECLARE @unpivot_cols_a NVARCHAR(MAX) = '';
    DECLARE @unpivot_cols_b NVARCHAR(MAX) = '';

    -- Get key info
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

    -- Get key expressions
    SELECT 
        @key_columns = STRING_AGG(QUOTENAME(c.name), ', '),
        @key_join = STRING_AGG('t1.' + QUOTENAME(c.name) + ' = t2.' + QUOTENAME(c.name), ' AND '),
        @key_isnullA = STRING_AGG('t2.' + QUOTENAME(c.name) + ' IS NULL', ' AND '),
        @key_isnullB = STRING_AGG('t1.' + QUOTENAME(c.name) + ' IS NULL', ' AND ')
    FROM sys.indexes i
    JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
    JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
    WHERE i.object_id = @object_id AND i.is_unique = 1 AND i.type IN (1, 2);

    IF @key_count = 1
        SELECT @key_concat_expr = STRING_AGG('CONVERT(NVARCHAR(100), t1.' + QUOTENAME(c.name) + ')', '')
        FROM sys.indexes i
        JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
        JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
        WHERE i.object_id = @object_id AND i.is_unique = 1 AND i.type IN (1, 2);
    ELSE
        SELECT @key_concat_expr = 'CONCAT_WS('':'', ' + STRING_AGG('CONVERT(NVARCHAR(100), t1.' + QUOTENAME(c.name) + ')', ', ') + ')'
        FROM sys.indexes i
        JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
        JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
        WHERE i.object_id = @object_id AND i.is_unique = 1 AND i.type IN (1, 2);

    -- Get non-key columns
    SELECT 
        @nonkey_columns = STRING_AGG(QUOTENAME(name), ', '),
        @select_diff_cols = STRING_AGG('t1.' + QUOTENAME(name) + ' AS a_' + name + ', t2.' + QUOTENAME(name) + ' AS b_' + name, ', '),
        @unpivot_cols_a = STRING_AGG('a_' + name, ', '),
        @unpivot_cols_b = STRING_AGG('b_' + name, ', ')
    FROM sys.columns
    WHERE object_id = @object_id 
      AND name NOT IN ('asof_dt', 'update_dt', 'revised_dt')
      AND name NOT IN (
            SELECT c.name
            FROM sys.indexes i
            JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
            JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
            WHERE i.object_id = @object_id AND i.is_unique = 1 AND i.type IN (1, 2)
        );

    IF @nonkey_columns IS NULL
    BEGIN
        PRINT 'Skipping ' + @table_name + ': No non-key columns to compare.';
        FETCH NEXT FROM table_cursor INTO @table_name;
        CONTINUE;
    END

    -- WHERE filter
    DECLARE @filter NVARCHAR(MAX) = '';
    IF @asof_dt IS NOT NULL SET @filter = 'WHERE asof_dt = @asof_dt';
    IF @update_dt IS NOT NULL SET @filter = 'WHERE update_dt = @update_dt';
    IF @asof_dt IS NOT NULL AND @update_dt IS NOT NULL SET @filter = 'WHERE asof_dt = @asof_dt AND update_dt = @update_dt';

    SET @sql = '
    SELECT * INTO #t1 FROM ' + QUOTENAME(@schemaA) + '.' + QUOTENAME(@table_name) + ' ' + @filter + ';
    SELECT * INTO #t2 FROM ' + QUOTENAME(@schemaB) + '.' + QUOTENAME(@table_name) + ' ' + @filter + ';

    -- Unpivot mismatched rows
    WITH Diff AS (
        SELECT ' + @key_concat_expr + ' AS mismatch_key, ' + @select_diff_cols + '
        FROM #t1 t1
        JOIN #t2 t2 ON ' + @key_join + '
    ),
    UnpivotedA AS (
        SELECT mismatch_key, col AS column_name, val1
        FROM Diff
        UNPIVOT (val1 FOR col IN (' + @unpivot_cols_a + ')) AS upvtA
    ),
    UnpivotedB AS (
        SELECT mismatch_key, col AS column_name, val2
        FROM Diff
        UNPIVOT (val2 FOR col IN (' + @unpivot_cols_b + ')) AS upvtB
    ),
    FinalDiff AS (
        SELECT 
            ''' + @table_name + ''' AS table_name,
            a.mismatch_key,
            REPLACE(a.column_name, ''a_'', '''') AS column_name,
            CONVERT(NVARCHAR(MAX), a.val1) AS value_schemaA,
            CONVERT(NVARCHAR(MAX), b.val2) AS value_schemaB
        FROM UnpivotedA a
        JOIN UnpivotedB b
            ON a.mismatch_key = b.mismatch_key AND a.column_name = b.column_name
        WHERE ISNULL(CONVERT(NVARCHAR(MAX), a.val1), ''<NULL>'') 
           <> ISNULL(CONVERT(NVARCHAR(MAX), b.val2), ''<NULL>'')
    )
    INSERT INTO dbo.recon_log (table_name, mismatch_key, column_name, value_schemaA, value_schemaB, schemaA, schemaB)
    SELECT table_name, mismatch_key, column_name, value_schemaA, value_schemaB, ''' + @schemaA + ''', ''' + @schemaB + '''
    FROM FinalDiff;

    -- Summary
    DECLARE @onlyA INT = (
        SELECT COUNT(1) FROM #t1 t1
        LEFT JOIN #t2 t2 ON ' + @key_join + '
        WHERE ' + @key_isnullA + '
    );

    DECLARE @onlyB INT = (
        SELECT COUNT(1) FROM #t2 t2
        LEFT JOIN #t1 t1 ON ' + @key_join + '
        WHERE ' + @key_isnullB + '
    );

    INSERT INTO dbo.recon_summary (
        table_name, total_rows_schemaA, total_rows_schemaB,
        matching_rows, column_mismatches, missing_in_schemaA, missing_in_schemaB,
        schemaA, schemaB
    )
    SELECT ''' + @table_name + ''' AS table_name,
           (SELECT COUNT(1) FROM #t1),
           (SELECT COUNT(1) FROM #t2),
           0,
           (SELECT COUNT(1) FROM dbo.recon_log WHERE table_name = ''' + @table_name + ''' AND schemaA = ''' + @schemaA + ''' AND schemaB = ''' + @schemaB + '''),
           @onlyB, @onlyA,
           ''' + @schemaA + ''', ''' + @schemaB + ''';

    DROP TABLE #t1;
    DROP TABLE #t2;
    ';

    EXEC sp_executesql @sql, N'@asof_dt DATETIME, @update_dt DATETIME', @asof_dt, @update_dt;

    FETCH NEXT FROM table_cursor INTO @table_name;
END

CLOSE table_cursor;
DEALLOCATE table_cursor;

-- Results
SELECT * FROM dbo.recon_log;
SELECT * FROM dbo.recon_summary;
