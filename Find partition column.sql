
SELECT  
    t.name AS [Table],  
    c.name AS [Partitioning Column], 
    TYPE_NAME(c.user_type_id) AS [Column Type], 
    ps.name AS [Partition Scheme]  
FROM sys.tables AS t    
JOIN sys.indexes AS i    
    ON t.[object_id] = i.[object_id]    
    AND i.[type] <= 1 
JOIN sys.partition_schemes AS ps    
    ON ps.data_space_id = i.data_space_id    
JOIN sys.index_columns AS ic    
    ON ic.[object_id] = i.[object_id]    
    AND ic.index_id = i.index_id    
    AND ic.partition_ordinal >= 1  
JOIN sys.columns AS c    
    ON t.[object_id] = c.[object_id]    
    AND ic.column_id = c.column_id    
WHERE schema_name(t.schema_id) = 'DataMart_MonthEndHistory'
and t.name = 'TransactionHistory'
