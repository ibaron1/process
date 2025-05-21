-- Assumptions:
-- #TableList contains a column called TableName (no schema prefix)
-- Source and Target schemas are defined below

DECLARE @SourceSchema NVARCHAR(128) = 'dbo';
DECLARE @TargetSchema NVARCHAR(128) = 'archive';

DECLARE @SQL VARCHAR(4000);

drop table if exists #TableList;
drop table if exists #WorkList;

create table #TableList(TableName VARCHAR(200));

INSERT #TableList
VALUES('DimProduct')
,('DimReseller')

DECLARE @i INT = 1, @maxRow INT
DECLARE @BatchSize INT  = 100

SELECT *, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RowNum
INTO #WorkList
FROM #TableList;

SELECT @maxRow = max(RowNum) FROM #WorkList;

DECLARE @j INT, @maxCurTbl INT;
DECLARE @TableName VARCHAR(200);
DECLARE @Table TABLE(TableName VARCHAR(200));

WHILE @i <= @maxRow
BEGIN
	DELETE @Table;

	--INSERT @Table
	SELECT @TableName = TableName
	FROM #WorkList
	WHERE RowNum = @i;

	SET @j = 1;

	SELECT @maxCurTbl = rows
	FROM sysindexes
	WHERE id = object_id(''+@SourceSchema+'.'+@TableName+'')
	AND indid in (0,1);

	DECLARE @ColumnList NVARCHAR(MAX);

	-- Get column list for the current table
	SELECT @ColumnList = STRING_AGG(QUOTENAME(COLUMN_NAME), ', ')
	FROM INFORMATION_SCHEMA.COLUMNS
	WHERE TABLE_SCHEMA = @SourceSchema AND TABLE_NAME = @TableName;

	WHILE @j <= @maxCurTbl
	BEGIN
		SET @SQL = 
		CONCAT('SET IDENTITY_INSERT ',@TargetSchema,'.',@TableName,' ON;
		WITH CTE_Batch AS (
			SELECT ', @ColumnList, ', ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RowNum
			FROM ',@SourceSchema,'.',@TableName,')
		INSERT ',@TargetSchema,'.',@TableName,' (', @ColumnList, ')
		SELECT ', @ColumnList, ' FROM CTE_Batch
		WHERE RowNum >= ', @j, ' AND RowNum < ', @j + @BatchSize, ';
		SET IDENTITY_INSERT ',@TargetSchema,'.',@TableName,' OFF;');


		--print @SQL;

		-- Execute it
		EXEC (@SQL);
		
		SET @j += @BatchSize;

		END;

SET @i +=1;
	
END;
