-- Parameters
DECLARE @SourceSchema SYSNAME = 'dbo';
DECLARE @TargetSchema SYSNAME = 'stage';

-- Variables
DECLARE @TableName SYSNAME;
DECLARE @SourceTable NVARCHAR(300);
DECLARE @TargetTable NVARCHAR(300);
DECLARE @SQL NVARCHAR(MAX);

-- Cursor to loop through table list
DECLARE table_cursor CURSOR FOR
SELECT TableName FROM dbo.TableList;

OPEN table_cursor;
FETCH NEXT FROM table_cursor INTO @TableName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SourceTable = QUOTENAME(@SourceSchema) + '.' + QUOTENAME(@TableName);
    SET @TargetTable = QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@TableName);

    SET @SQL = '
    INSERT INTO ' + @TargetTable + '
    SELECT * FROM ' + @SourceTable + ';';

    PRINT 'Copying data from ' + @SourceTable + ' to ' + @TargetTable;
    EXEC sp_executesql @SQL;

    FETCH NEXT FROM table_cursor INTO @TableName;
END

CLOSE table_cursor;
DEALLOCATE table_cursor;
