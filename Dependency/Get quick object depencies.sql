SELECT referenced_entity_name, referenced_schema_name, OBJECT_NAME(referencing_id) AS ReferencingObj, 
				(SELECT SCHEMA_NAME(schema_id) FROM sys.objects WHERE OBJECT_ID = referencing_id) AS Referencing_schema_name
FROM sys.sql_expression_dependencies
WHERE referenced_id = OBJECT_ID(N'DataMart_Log.Update_DailyRuleTables_log')