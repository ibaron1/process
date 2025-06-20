-- Parameters
DECLARE @SourceSchema SYSNAME = 'source';
DECLARE @TargetSchema SYSNAME = 'target';
DECLARE @BatchSize INT = 10000;

-- Variables
DECLARE @TableName SYSNAME;
DECLARE @SQL NVARCHAR(MAX);
DECLARE @RowCount INT;
DECLARE @Offset INT;

-- Cursor to loop through table list
DECLARE table_cursor CURSOR FOR
SELECT TableName FROM dbo.TableList;

OPEN table_cursor;
FETCH NEXT FROM table_cursor INTO @TableName;

WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @SourceTable NVARCHAR(300) = QUOTENAME(@SourceSchema) + '.' + QUOTENAME(@TableName);
    DECLARE @TargetTable NVARCHAR(300) = QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@TableName);
    SET @Offset = 0;
    SET @RowCount = 1;

    -- Get column list in physical order by column_id
    DECLARE @ColumnList NVARCHAR(MAX);
    SELECT @ColumnList = STRING_AGG(QUOTENAME(name), ', ')
    FROM (
        SELECT top 100 percent name
        FROM sys.columns
        WHERE object_id = OBJECT_ID(@SourceTable)
        ORDER BY column_id
    ) AS OrderedCols;

    -- Detect if destination table has an identity column
    DECLARE @HasIdentity BIT = 0;
    SELECT @HasIdentity = 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID(@TargetTable)
      AND is_identity = 1;

    PRINT 'Copying data from ' + @SourceTable + ' to ' + @TargetTable;

    WHILE @RowCount > 0
    BEGIN
        SET @SQL = '';

        -- Optionally enable IDENTITY_INSERT
        IF @HasIdentity = 1
            SET @SQL += 'SET IDENTITY_INSERT ' + @TargetTable + ' ON; ';

        -- Insert batch
        SET @SQL += '
        INSERT INTO ' + @TargetTable + ' (' + @ColumnList + ')
        SELECT ' + @ColumnList + '
        FROM ' + @SourceTable + '
        ORDER BY (SELECT NULL)
        OFFSET ' + CAST(@Offset AS VARCHAR) + ' ROWS
        FETCH NEXT ' + CAST(@BatchSize AS VARCHAR) + ' ROWS ONLY;';

        -- Optionally disable IDENTITY_INSERT
        IF @HasIdentity = 1
            SET @SQL += ' SET IDENTITY_INSERT ' + @TargetTable + ' OFF; ';

        EXEC sp_executesql @SQL;

        SET @RowCount = @@ROWCOUNT;
        SET @Offset += @BatchSize;
    END

    PRINT 'Finished copying: ' + @SourceTable;

    FETCH NEXT FROM table_cursor INTO @TableName;
END

CLOSE table_cursor;
DEALLOCATE table_cursor;
