-- Create and populate TableList
if object_id('dbo.TableList') is null
begin
CREATE TABLE dbo.TableList(tbl VARCHAR(200));
INSERT INTO dbo.TableList(tbl) VALUES
('Sales.Customer'),
('Sales.SalesPerson'),
('Sales.SpecialOffer'),
('Sales.SalesOrderHeader'),
('Sales.SalesOrderHeader'),
('Sales.SpecialOfferProduct');
end;

-- Assumes: TableList(tbl VARCHAR(200)) contains schema-qualified names like 'dbo.Customers'
;WITH ParsedTableList AS (
    SELECT 
        tbl,
        PARSENAME(tbl, 1) AS TableName,
        PARSENAME(tbl, 2) AS SchemaName
    FROM TableList
),
-- Lookup object_id for tables in the list
ListedParents AS (
    SELECT 
        t.object_id,
        s.name AS SchemaName,
        t.name AS TableName,
        CONCAT(s.name, '.', t.name) AS FullName
    FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    JOIN ParsedTableList l ON l.SchemaName = s.name AND l.TableName = t.name
),
-- FK relationships where parent is in list (child can be anything)
FKsFromListedParents AS (
    SELECT DISTINCT
        CONCAT(sParent.name, '.', tParent.name) AS ParentTable,
        CONCAT(sChild.name, '.', tChild.name) AS ChildTable
    FROM sys.foreign_keys fk
    JOIN sys.tables tParent ON fk.referenced_object_id = tParent.object_id
    JOIN sys.schemas sParent ON tParent.schema_id = sParent.schema_id
    JOIN sys.tables tChild ON fk.parent_object_id = tChild.object_id
    JOIN sys.schemas sChild ON tChild.schema_id = sChild.schema_id
    -- Only include if parent is in the list
    JOIN ListedParents lp ON lp.object_id = tParent.object_id
),
-- Distinct parent tables from list
UniqueParents AS (
    SELECT DISTINCT 
        ParentTable AS TableName,
        'Parent' AS RelationshipType,
        ParentTable AS ParentKey
    FROM FKsFromListedParents
),
-- Distinct children (may be outside the list)
UniqueChildren AS (
    SELECT DISTINCT 
        ChildTable AS TableName,
        'Child' AS RelationshipType,
        ParentTable AS ParentKey
    FROM FKsFromListedParents
)
-- Final ordered result
SELECT *
FROM (
    SELECT * FROM UniqueParents
    UNION ALL
    SELECT * FROM UniqueChildren
) AS Combined
ORDER BY 
    ParentKey,
    CASE WHEN RelationshipType = 'Parent' THEN 0 ELSE 1 END,
    TableName;
