WITH StatsInfo AS (
    SELECT 
        OBJECT_NAME(s.object_id) AS TableName,
        s.name AS StatisticName,
        sp.rows AS TotalRows,
        sp.modification_counter AS RowsModified,
        (CASE 
            WHEN sp.rows < 500 THEN 500  -- Threshold for small tables -> tables with fewer than 500 rows (update statistics when 500 modifications occur)
            ELSE (sp.rows * 0.2 + 500)  -- Threshold for larger tables -> Larger tables (update statistics when 20% + 500 modifications occur)
        END) AS Threshold,
        s.is_incremental AS IsIncremental
    FROM sys.stats s
    CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
    WHERE OBJECT_SCHEMA_NAME(s.object_id) NOT IN ('sys', 'INFORMATION_SCHEMA') -- Exclude system tables
)
SELECT 
    TableName, 
    StatisticName, 
    TotalRows, 
    RowsModified, 
    Threshold,
    IsIncremental
INTO #StaleStats
FROM StatsInfo
WHERE RowsModified >= Threshold;

DECLARE @TableName NVARCHAR(128);
DECLARE @StatisticName NVARCHAR(128);
DECLARE @IsIncremental TINYINT;
DECLARE update_cursor CURSOR FOR 
SELECT TableName, StatisticName, IsIncremental FROM #StaleStats;

OPEN update_cursor;
FETCH NEXT FROM update_cursor INTO @TableName, @StatisticName, @IsIncremental;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF @IsIncremental = 1
    BEGIN
        PRINT 'Updating incremental statistics for ' + @TableName + ', Statistic: ' + @StatisticName;
        EXEC('UPDATE STATISTICS ' + @TableName + ' ' + @StatisticName + ' WITH RESAMPLE');
    END
    ELSE
    BEGIN
        PRINT 'Updating standard statistics for ' + @TableName;
        EXEC('UPDATE STATISTICS ' + @TableName);
    END

    FETCH NEXT FROM update_cursor INTO @TableName, @StatisticName, @IsIncremental;
END;

CLOSE update_cursor;
DEALLOCATE update_cursor;

DROP TABLE #StaleStats;
