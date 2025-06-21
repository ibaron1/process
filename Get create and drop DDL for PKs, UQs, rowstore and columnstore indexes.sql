SELECT 
    s.name AS SchemaName,
    t.name AS TableName,
    i.name AS IndexName,
    i.index_id,
    i.type_desc AS IndexType,
    i.is_unique AS IsUnique,
    kc.name AS ConstraintName,
    kc.type_desc AS ConstraintType,
    ds.name AS DataSpaceName,
    ds.type_desc AS DataSpaceType,
    ps.name AS PartitionSchemeName
FROM 
    sys.indexes i
INNER JOIN 
    sys.tables t ON i.object_id = t.object_id
INNER JOIN 
    sys.schemas s ON t.schema_id = s.schema_id
LEFT JOIN 
    sys.key_constraints kc 
        ON kc.parent_object_id = i.object_id 
        AND kc.unique_index_id = i.index_id
LEFT JOIN 
    sys.data_spaces ds ON i.data_space_id = ds.data_space_id
LEFT JOIN 
    sys.partition_schemes ps ON ds.data_space_id = ps.data_space_id
WHERE 
    t.is_ms_shipped = 0
    AND i.is_hypothetical = 0
    AND i.type_desc <> 'HEAP'  -- Exclude heaps (no index)
ORDER BY 
    s.name, t.name, i.index_id;
