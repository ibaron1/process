WITH ParsedTableList AS (
    SELECT 
        tbl,
        PARSENAME(tbl, 1) AS TableName,
        PARSENAME(tbl, 2) AS SchemaName
    FROM TableList
),

FilteredParents AS (
    SELECT DISTINCT
        CONCAT(sp.name, '.', p.name) AS TableName,
        'Parent' AS RelationshipType,
        CONCAT(sp.name, '.', p.name) AS ParentKey
    FROM sys.tables p
    JOIN sys.schemas sp ON p.schema_id = sp.schema_id
    JOIN ParsedTableList l ON sp.name = l.SchemaName AND p.name = l.TableName
    WHERE EXISTS (
        SELECT 1
        FROM sys.foreign_keys fk
        JOIN sys.tables c ON fk.parent_object_id = c.object_id
        JOIN sys.schemas sc ON c.schema_id = sc.schema_id
        JOIN ParsedTableList lc ON sc.name = lc.SchemaName AND c.name = lc.TableName
        WHERE fk.referenced_object_id = p.object_id
    )
),

FilteredChildren AS (
    SELECT DISTINCT
        CONCAT(sc.name, '.', c.name) AS TableName,
        'Child' AS RelationshipType,
        CONCAT(sp.name, '.', p.name) AS ParentKey
    FROM sys.foreign_keys fk
    JOIN sys.tables c ON fk.parent_object_id = c.object_id
    JOIN sys.schemas sc ON c.schema_id = sc.schema_id
    JOIN ParsedTableList lc ON sc.name = lc.SchemaName AND c.name = lc.TableName
    JOIN sys.tables p ON fk.referenced_object_id = p.object_id
    JOIN sys.schemas sp ON p.schema_id = sp.schema_id
    JOIN ParsedTableList lp ON sp.name = lp.SchemaName AND p.name = lp.TableName
)

SELECT *
FROM (
    SELECT * FROM FilteredParents
    UNION ALL
    SELECT * FROM FilteredChildren
) AS Combined
ORDER BY 
    ParentKey,
    CASE WHEN RelationshipType = 'Parent' THEN 0 ELSE 1 END,
    TableName;
