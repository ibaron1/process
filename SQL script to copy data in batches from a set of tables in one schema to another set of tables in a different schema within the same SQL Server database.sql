DECLARE @BatchSize INT = 1000; -- Number of rows to copy in each batch
DECLARE @SourceSchema NVARCHAR(128) = 'SourceSchema';
DECLARE @TargetSchema NVARCHAR(128) = 'TargetSchema';
DECLARE @TableName NVARCHAR(128);
DECLARE @RowCount INT;

-- Temporary table to hold the list of tables to process
CREATE TABLE #TableList (TableName NVARCHAR(128));

-- Populate the table list (adjust the WHERE clause as needed)
INSERT INTO #TableList (TableName)
SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = @SourceSchema AND TABLE_TYPE = 'BASE TABLE';

-- Cursor to iterate through each table
DECLARE TableCursor CURSOR FOR
SELECT TableName FROM #TableList;

OPEN TableCursor;
FETCH NEXT FROM TableCursor INTO @TableName;

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT 'Processing table: ' + @TableName;

    -- Initialize row count
    SET @RowCount = 1;

    WHILE @RowCount > 0
    BEGIN
        -- Copy data in batches
        WITH CTE_Batch AS (
            SELECT TOP (@BatchSize) *
            FROM [@SourceSchema].[@TableName]
            WHERE NOT EXISTS (
                SELECT 1
                FROM [@TargetSchema].[@TableName] T
                WHERE T.PrimaryKeyColumn = [@SourceSchema].[@TableName].PrimaryKeyColumn
            )
        )
        INSERT INTO [@TargetSchema].[@TableName]
        SELECT * FROM CTE_Batch;

        -- Get the number of rows copied
        SET @RowCount = @@ROWCOUNT;

        PRINT CAST(@RowCount AS NVARCHAR) + ' rows copied for table ' + @TableName;
    END

    FETCH NEXT FROM TableCursor INTO @TableName;
END

CLOSE TableCursor;
DEALLOCATE TableCursor;

-- Clean up
DROP TABLE #TableList;

PRINT 'Data copy completed.';
