SELECT 
    'ALTER TABLE [' + sch.name + '].[' + parent.name + '] DROP CONSTRAINT [' + fk.name + '];' AS DropStmt,
    'ALTER TABLE [' + sch.name + '].[' + parent.name + '] ADD CONSTRAINT [' + fk.name + '] FOREIGN KEY (' + 
        STUFF((SELECT ', [' + COL_NAME(fc.parent_object_id, fc.parent_column_id) + ']'
               FROM sys.foreign_key_columns fc
               WHERE fc.constraint_object_id = fk.object_id
               FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '') +
    ') REFERENCES [' + refsch.name + '].[' + ref.name + '] (' + 
        STUFF((SELECT ', [' + COL_NAME(fc.referenced_object_id, fc.referenced_column_id) + ']'
               FROM sys.foreign_key_columns fc
               WHERE fc.constraint_object_id = fk.object_id
               FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '') + ');' AS CreateStmt
FROM 
    sys.foreign_keys fk
    INNER JOIN sys.tables parent ON fk.parent_object_id = parent.object_id
    INNER JOIN sys.tables ref ON fk.referenced_object_id = ref.object_id
    INNER JOIN sys.schemas sch ON parent.schema_id = sch.schema_id
    INNER JOIN sys.schemas refsch ON ref.schema_id = refsch.schema_id;
