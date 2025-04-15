SELECT 
    'ALTER TABLE [' + s.name + '].[' + t.name + '] DROP CONSTRAINT [' + i.name + '];' AS DropStmt,
    'ALTER TABLE [' + s.name + '].[' + t.name + '] ADD CONSTRAINT [' + i.name + '] ' +
    CASE 
        WHEN i.is_primary_key = 1 THEN 'PRIMARY KEY '
        WHEN i.is_unique = 1 THEN 'UNIQUE '
    END +
    CASE 
        WHEN i.type_desc = 'CLUSTERED' THEN 'CLUSTERED '
        WHEN i.type_desc = 'NONCLUSTERED' THEN 'NONCLUSTERED '
    END +
    '(' + 
    STRING_AGG(c.name, ', ') WITHIN GROUP (ORDER BY ic.key_ordinal) 
    + ')' +
    CASE 
        WHEN ps.name IS NOT NULL THEN ' ON [' + ps.name + ']([' + pc.name + '])'
        ELSE ''
    END + ';' AS CreateStmt
FROM 
    sys.indexes i
    JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
    JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
    JOIN sys.tables t ON i.object_id = t.object_id
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    LEFT JOIN sys.data_spaces ds ON i.data_space_id = ds.data_space_id
    LEFT JOIN sys.partition_schemes ps ON ds.data_space_id = ps.data_space_id
    LEFT JOIN sys.index_columns ipc ON ipc.object_id = i.object_id AND ipc.index_id = i.index_id AND ipc.partition_ordinal = 1
    LEFT JOIN sys.columns pc ON pc.object_id = i.object_id AND pc.column_id = ipc.column_id
WHERE 
    (i.is_primary_key = 1 OR i.is_unique = 1)
GROUP BY 
    s.name, t.name, i.name, i.is_primary_key, i.is_unique, i.type_desc, ps.name, pc.name;
