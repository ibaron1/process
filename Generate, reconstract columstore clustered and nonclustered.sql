--sql server 2017 up

SELECT 
    'CREATE ' + 
    CASE 
        WHEN i.type = 6 THEN 'CLUSTERED ' 
        WHEN i.type = 5 THEN 'NONCLUSTERED ' 
    END + 
    'COLUMNSTORE INDEX [' + i.name + '] ON [' + s.name + '].[' + t.name + ']' +
    CASE 
        WHEN i.type = 5 THEN
            ' (' + 
            STRING_AGG(CAST(c.name AS NVARCHAR(MAX)), ', ') 
                WITHIN GROUP (ORDER BY ic.key_ordinal) + 
            ')'
        ELSE ''
    END + ';' AS create_index_sql
FROM 
    sys.indexes i
JOIN sys.tables t ON i.object_id = t.object_id
JOIN sys.schemas s ON t.schema_id = s.schema_id
LEFT JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
LEFT JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE 
    i.type IN (5, 6) -- 5 = Nonclustered Columnstore, 6 = Clustered Columnstore
GROUP BY 
    i.name, i.type, s.name, t.name;

-- pre sql server 2017

SELECT DISTINCT
    'CREATE ' + 
    CASE 
        WHEN i.type = 6 THEN 'CLUSTERED ' 
        WHEN i.type = 5 THEN 'NONCLUSTERED ' 
    END + 
    'COLUMNSTORE INDEX [' + i.name + '] ON [' + s.name + '].[' + t.name + ']' +
    CASE 
        WHEN i.type = 5 THEN
            ' (' + 
            STUFF((
                SELECT ', ' + QUOTENAME(c2.name)
                FROM sys.index_columns ic2
                JOIN sys.columns c2 ON ic2.object_id = c2.object_id AND ic2.column_id = c2.column_id
                WHERE ic2.object_id = i.object_id AND ic2.index_id = i.index_id
                ORDER BY ic2.key_ordinal
                FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '') +
            ')'
        ELSE ''
    END + ';' AS create_index_sql
FROM 
    sys.indexes i
JOIN sys.tables t ON i.object_id = t.object_id
JOIN sys.schemas s ON t.schema_id = s.schema_id
LEFT JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
LEFT JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE 
    i.type IN (5, 6) -- Columnstore indexes only
