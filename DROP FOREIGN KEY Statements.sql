SELECT
    'ALTER TABLE ' + QUOTENAME(SCHEMA_NAME(tp.schema_id)) + '.' + QUOTENAME(tp.name) +
    ' DROP CONSTRAINT ' + QUOTENAME(fk.name) + ';' AS DropFKStatement
FROM sys.foreign_keys fk
JOIN sys.tables tp ON fk.parent_object_id = tp.object_id
JOIN sys.schemas sp ON tp.schema_id = sp.schema_id
--JOIN dbo.TableList l ON QUOTENAME(sp.name) + '.' + QUOTENAME(tp.name) = l.TableName
ORDER BY tp.name, fk.name;
