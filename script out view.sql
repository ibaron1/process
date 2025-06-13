
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

 --============ View Definition + Referenced Tables =============--

  --================= Script All Views in a Schema ===--
  SELECT 
    'CREATE VIEW [' + SCHEMA_NAME(v.schema_id) + '].[' + v.name + '] AS ' + CHAR(13) + CHAR(10) + m.definition AS ViewDefinition
FROM sys.views v
JOIN sys.sql_modules m ON v.object_id = m.object_id
WHERE SCHEMA_NAME(v.schema_id) = 'dbo';
