use WideWorldImporters
go
-- objects referenced by specified stored proc
;WITH ref_list AS
    (SELECT o.object_id, OBJECT_SCHEMA_NAME(o.object_id) AS schema_name, o.name AS object_name, o.type_desc
       FROM sys.sql_expression_dependencies ed
       INNER JOIN sys.objects o ON ed.referenced_id = o.object_id
       WHERE ed.referencing_id = OBJECT_ID('Integration.GetCustomerUpdates','P')
         AND ed.referenced_id <> ed.referencing_id
     UNION ALL
     SELECT o2.object_id, OBJECT_SCHEMA_NAME(o2.object_id) AS schema_name, o2.name AS object_name, o2.type_desc
       FROM ref_list rl
       INNER JOIN sys.sql_expression_dependencies ed2 ON rl.object_id = ed2.referencing_id
       INNER JOIN sys.objects o2 ON ed2.referenced_id = o2.object_id
       WHERE ed2.referenced_id <> ed2.referencing_id
      )
SELECT DISTINCT schema_name, object_name, type_desc
  FROM ref_list 