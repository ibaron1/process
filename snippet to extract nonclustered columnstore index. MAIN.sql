SELECT 
    t.name AS TableName,
    i.name AS IndexName,
    'CREATE NONCLUSTERED COLUMNSTORE INDEX ' + QUOTENAME(i.name) + ' ON ' + QUOTENAME(s.name) + '.' + QUOTENAME(t.name) + 
    ' (' +  
        STUFF((
            SELECT ', ' + QUOTENAME(c.name)
            FROM sys.index_columns ic
            JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
            WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id
			AND NOT EXISTS
				(SELECT 1 
				 FROM sys.indexes AS i1 
				 JOIN sys.partition_schemes AS ps    
					 ON ps.data_space_id = i1.data_space_id AND i1.[type] <= 1 
					 AND i1.[object_id] = i.[object_id]    
				 JOIN sys.index_columns AS ic    
					ON ic.[object_id] = i.[object_id] AND ic.index_id = i.index_id  AND ic.partition_ordinal >= 1
				 JOIN sys.columns c1 ON ic.object_id = c.object_id AND ic.column_id = c.column_id
					WHERE c1.name = c.name )    
            ORDER BY ic.key_ordinal
            FOR XML PATH(''), TYPE
        ).value('.', 'NVARCHAR(MAX)'), 1, 2, '')
    + ');' AS IndexDefinition
FROM sys.indexes i
JOIN sys.tables t ON i.object_id = t.object_id
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE i.type = 6 -- 6 represents a nonclustered columnstore index
