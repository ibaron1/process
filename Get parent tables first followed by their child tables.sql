WITH ForeignKeyHierarchy AS (
    -- Base case: tables with no foreign key dependencies (i.e., top-level referenced tables)
    SELECT 
        fk.parent_object_id,
        fk.referenced_object_id,
        p.name AS ParentTableSchema,
        OBJECT_NAME(fk.parent_object_id) AS ParentTable,
        r.name AS ReferencedTableSchema,
        OBJECT_NAME(fk.referenced_object_id) AS ReferencedTable,
        0 AS Level
    FROM sys.foreign_keys fk
    JOIN sys.objects po ON fk.parent_object_id = po.object_id
    JOIN sys.objects ro ON fk.referenced_object_id = ro.object_id
    JOIN sys.schemas p ON po.schema_id = p.schema_id
    JOIN sys.schemas r ON ro.schema_id = r.schema_id

    UNION ALL

    -- Recursive case: follow the foreign key dependency chain
    SELECT 
        fk.parent_object_id,
        fk.referenced_object_id,
        p.name AS ParentTableSchema,
        OBJECT_NAME(fk.parent_object_id) AS ParentTable,
        r.name AS ReferencedTableSchema,
        OBJECT_NAME(fk.referenced_object_id) AS ReferencedTable,
        fkh.Level + 1
    FROM sys.foreign_keys fk
    JOIN ForeignKeyHierarchy fkh ON fk.referenced_object_id = fkh.parent_object_id
    JOIN sys.objects po ON fk.parent_object_id = po.object_id
    JOIN sys.objects ro ON fk.referenced_object_id = ro.object_id
    JOIN sys.schemas p ON po.schema_id = p.schema_id
    JOIN sys.schemas r ON ro.schema_id = r.schema_id
)
-- Final selection with unique list of involved tables, ordered by dependency level
SELECT DISTINCT
    OBJECT_SCHEMA_NAME(referenced_object_id) AS TableSchema,
    OBJECT_NAME(referenced_object_id) AS TableName,
    MIN(Level) AS DependencyLevel
FROM ForeignKeyHierarchy
GROUP BY referenced_object_id
UNION
SELECT DISTINCT
    OBJECT_SCHEMA_NAME(parent_object_id),
    OBJECT_NAME(parent_object_id),
    MIN(Level) + 1
FROM ForeignKeyHierarchy
GROUP BY parent_object_id
ORDER BY DependencyLevel, TableSchema, TableName;
