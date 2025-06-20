SELECT
    'ALTER TABLE ' + QUOTENAME(SCHEMA_NAME(tp.schema_id)) + '.' + QUOTENAME(tp.name) + CHAR(13) +
    'ADD CONSTRAINT ' + QUOTENAME(fk.name) + CHAR(13) +
    'FOREIGN KEY (' + STRING_AGG(QUOTENAME(cp.name), ', ') WITHIN GROUP (ORDER BY ic.constraint_column_id) + ')' + CHAR(13) +
    'REFERENCES ' + QUOTENAME(SCHEMA_NAME(tr.schema_id)) + '.' + QUOTENAME(tr.name) + ' (' +
        STRING_AGG(QUOTENAME(cr.name), ', ') WITHIN GROUP (ORDER BY ic.constraint_column_id) + ');'
    AS CreateFKStatement
FROM sys.foreign_keys fk
JOIN sys.foreign_key_columns ic ON ic.constraint_object_id = fk.object_id
JOIN sys.tables tp ON fk.parent_object_id = tp.object_id
JOIN sys.schemas sp ON tp.schema_id = sp.schema_id
JOIN sys.columns cp ON cp.object_id = tp.object_id AND cp.column_id = ic.parent_column_id
JOIN sys.tables tr ON fk.referenced_object_id = tr.object_id
JOIN sys.schemas sr ON tr.schema_id = sr.schema_id
JOIN sys.columns cr ON cr.object_id = tr.object_id AND cr.column_id = ic.referenced_column_id
--JOIN dbo.TableList l ON QUOTENAME(sp.name) + '.' + QUOTENAME(tp.name) = l.TableName
GROUP BY fk.name, tp.name, tp.schema_id, tr.name, tr.schema_id
ORDER BY tp.name, fk.name;
