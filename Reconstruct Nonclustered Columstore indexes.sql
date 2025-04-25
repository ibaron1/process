SELECT 
    'CREATE NONCLUSTERED COLUMNSTORE INDEX [' + i.name + '] ON [' + s.name + '].[' + t.name + '] (' +
    STRING_AGG(CAST(QUOTENAME(c.name) AS NVARCHAR(MAX)), ', ') WITHIN GROUP (ORDER BY ic.key_ordinal) + ')' +
    ISNULL(' ON [' + ps.name + ']([' + pc.name + '])', '') + ';' AS create_index_sql
FROM 
    sys.indexes i
JOIN sys.tables t ON i.object_id = t.object_id
JOIN sys.schemas s ON t.schema_id = s.schema_id
JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
LEFT JOIN sys.partition_schemes ps ON i.data_space_id = ps.data_space_id
LEFT JOIN sys.index_columns icp ON i.object_id = icp.object_id AND i.index_id = icp.index_id AND icp.partition_ordinal = 1
LEFT JOIN sys.columns pc ON icp.object_id = pc.object_id AND icp.column_id = pc.column_id
WHERE 
    i.type = 5 -- Nonclustered Columnstore
GROUP BY 
    i.name, s.name, t.name, ps.name, pc.name;

/*
--pre sql server 2017
SELECT DISTINCT
    'CREATE NONCLUSTERED COLUMNSTORE INDEX [' + i.name + '] ON [' + s.name + '].[' + t.name + '] (' +
    STUFF((
        SELECT ', ' + QUOTENAME(c2.name)
        FROM sys.index_columns ic2
        JOIN sys.columns c2 ON ic2.object_id = c2.object_id AND ic2.column_id = c2.column_id
        WHERE ic2.object_id = i.object_id AND ic2.index_id = i.index_id
        ORDER BY ic2.key_ordinal
        FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '') + ')' +
    ISNULL(
        ' ON [' + ps.name + ']([' + pc.name + '])',
        ''
    ) + ';' AS create_index_sql
FROM 
    sys.indexes i
JOIN sys.tables t ON i.object_id = t.object_id
JOIN sys.schemas s ON t.schema_id = s.schema_id
LEFT JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
LEFT JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
LEFT JOIN sys.partition_schemes ps ON i.data_space_id = ps.data_space_id
LEFT JOIN sys.index_columns icp ON i.object_id = icp.object_id AND i.index_id = icp.index_id AND icp.partition_ordinal = 1
LEFT JOIN sys.columns pc ON icp.object_id = pc.object_id AND icp.column_id = pc.column_id
WHERE 
    i.type = 5 -- Nonclustered Columnstore
*/