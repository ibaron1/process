DECLARE @schema varchar(100) = 'ApplicationData';
SELECT 
    fk.name AS ForeignKeyName,
    sch_ref.name AS ReferencedSchema,
    tab_ref.name AS ReferencedTable,
    sch_refg.name AS ReferencingSchema,
    tab_refg.name AS ReferencingTable
FROM 
    sys.foreign_keys fk
INNER JOIN 
    sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
INNER JOIN 
    sys.tables tab_refg ON fkc.parent_object_id = tab_refg.object_id
INNER JOIN 
    sys.schemas sch_refg ON tab_refg.schema_id = sch_refg.schema_id
INNER JOIN 
    sys.tables tab_ref ON fkc.referenced_object_id = tab_ref.object_id
INNER JOIN 
    sys.schemas sch_ref ON tab_ref.schema_id = sch_ref.schema_id
where sch_ref.name = @schema
GROUP BY 
    fk.name, sch_ref.name, tab_ref.name, sch_refg.name, tab_refg.name
ORDER BY 
    ReferencedSchema, ReferencedTable, ReferencingSchema, ReferencingTable;
