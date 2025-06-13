
 --============ View Definition + Referenced Tables =============--
 DECLARE @ViewSchema SYSNAME = 'dbo';
DECLARE @ViewName SYSNAME = 'YourViewName';

-- 1. Get the CREATE VIEW definition
-- Extract and split definition line-by-line
SELECT 
    LineNumber = ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
    Line = LTRIM(RTRIM(value))
FROM (
    SELECT definition
    FROM sys.sql_modules sm
    JOIN sys.objects o ON sm.object_id = o.object_id
    JOIN sys.schemas s ON o.schema_id = s.schema_id
    WHERE s.name = @ViewSchema AND o.name = @ViewName
) AS src
CROSS APPLY STRING_SPLIT(src.definition, CHAR(10));  -- Split by line feed
;

-- 2. Get the referenced tables
SELECT 
    ReferencedSchema = referenced_schema_name,
    ReferencedEntity = referenced_entity_name,
    ReferencedType = referenced_minor_name, -- e.g., column if applicable
    ReferencedObjectType = o.type_desc
FROM sys.dm_sql_referenced_entities(
        QUOTENAME(@ViewSchema) + '.' + QUOTENAME(@ViewName), 
        'OBJECT'
    ) d
LEFT JOIN sys.objects o 
    ON OBJECT_ID(QUOTENAME(d.referenced_schema_name) + '.' + QUOTENAME(d.referenced_entity_name)) = o.object_id
WHERE is_ambiguous = 0;

--======================================================================================================================
DECLARE @ViewSchema SYSNAME = 'dbo';
DECLARE @ViewName SYSNAME = 'YourViewName';

SELECT 
    definition = OBJECT_DEFINITION(OBJECT_ID(QUOTENAME(@ViewSchema) + '.' + QUOTENAME(@ViewName)))

--========================
SELECT sm.definition
FROM sys.views v
JOIN sys.sql_modules sm ON v.object_id = sm.object_id
WHERE v.name = 'YourViewName'
  AND SCHEMA_NAME(v.schema_id) = 'dbo';

  --================= Script All Views in a Schema ===--
  SELECT 
    'CREATE VIEW [' + SCHEMA_NAME(v.schema_id) + '].[' + v.name + '] AS ' + CHAR(13) + CHAR(10) + m.definition AS ViewDefinition
FROM sys.views v
JOIN sys.sql_modules m ON v.object_id = m.object_id
WHERE SCHEMA_NAME(v.schema_id) = 'dbo';
