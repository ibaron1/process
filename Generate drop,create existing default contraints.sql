-- This script generates the DROP and CREATE statements for default constraints
SELECT 
    'ALTER TABLE [' + sch.name + '].[' + t.name + '] DROP CONSTRAINT [' + dc.name + '];' AS DropStmt,
    'ALTER TABLE [' + sch.name + '].[' + t.name + '] ADD CONSTRAINT [' + dc.name + '] DEFAULT ' + dc.definition + ' FOR [' + c.name + '];' AS CreateStmt
FROM 
    sys.default_constraints dc
    INNER JOIN sys.columns c ON c.default_object_id = dc.object_id
    INNER JOIN sys.tables t ON c.object_id = t.object_id
    INNER JOIN sys.schemas sch ON t.schema_id = sch.schema_id
where concat(quotename(sch.name),'.',quotename(t.name)) = '[Person].[Address]'
ORDER BY 
    t.name, c.column_id;
