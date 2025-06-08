DECLARE @SchemaName VARCHAR(40) = 'DataMart_MonthEndHistory'; -- specific schema; null - all schemas

DECLARE @tbl TABLE(TableName VARCHAR(400));

/*
-- 1.Get indexes for object's dependent tables (sprocs, triggers, views, functions)
DECLARE @object_id int = OBJECT_ID('iborop.fr_cp_non_col_fx_risk_detail_load');

/*
insert @tbl
values('rep_br_sm_udf' ), ('rep_br_ibnd_data' ), ('rep_br_cusip_alias' ), ('rep_br_sm_sector' ), ('qr_industry_correlatioN')
*/

INSERT @tb1
SELECT DISTINCT referenced_entity_name
FROM sys.sql_expression_dependencies
NHERE referencIng_id = @object_id
AND OBJECTPROPERTY(referenced_id, 'IsTable') = 1

insert @tbl
values('arms_calc_corr_matrix_model' ), ('arms_calc_corr_matrix_dynamic' )

insert @tbl
select * from dbo.tblist as 1

SELECT *
From tblist

insert @tbl
values('qrrmexcessreturN')
*/

-- select * from @tbl
/*
SELECT DISTINCT referenced_entity_name, 'IsProcedure' as CalledObject
FROM sys.sql_expression_dependencies
NHERE referencIng_id = @object_id
AND OBJECTPROPERTY(referenced_id, 'IsProcedure' ) = 1
*/

SELECT
DB_NAME () AS [database_name],
sc.[name] + N'.' + t.[name] AS table_name,
si.index_id,
si.[name] AS index_name,
si.[type_desc],
STATS_DATE (si.object_id , si.index_id) StatisticsUpdate,
(SELECT MAX( [value].[user_reads])
FROM (VALUES (last_user_seek), (last_user_scan), (last_user_lookup) ) AS value(user_reads)) AS last_user_read,
[stat].[last_user_update],
CASE si.index_id WHEN 0 THEN N'/* No create statement (Heap) */'
ELSE
CASE
WHEN [si].[is_primary_key] = 1 THEN
'IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = ''' + si.name + ''' AND OBJECT_SCHEMA_NAME(object_id) = '''+sc.name+''') ' +
N'ALTER TABLE ' + QUOTENAME(sc.name) + N'.' + QUOTENAME(t.name) + N' ADD CONSTRAINT ' + QUOTENAME(si.name) + N' PRIMARY KEY ' +
CASE WHEN si.index_id > 1 THEN N'NON' ELSE N'' END + N'CLUSTERED '
WHEN [si].[is_unique] = 1 THEN
'IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = ''' + si.name + ''' AND OBJECT_SCHEMA_NAME(object_id) = '''+sc.name+''' ) ' +
N'ALTER TABLE ' + QUOTENAME(sc.name) + N'.' + QUOTENAME(t.name) + N' ADD CONSTRAINT ' + QUOTENAME(si.name) + N' UNIQUE ' +
CASE WHEN si.index_id > 1 THEN N'NON' ELSE N'' END + N'CLUSTERED '
ELSE
'IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = ''' + si.name + ''' AND OBJECT_SCHEMA_NAME(object_id) = '' '+sc.name+''' ) ' +
N'CREATE ' +
CASE WHEN [si].[is_unique] = 1 then N'UNIQUE ' ELSE N'' END +
CASE WHEN si.index_id > 1 THEN N'NON' ELSE N'' END + N'CLUSTERED ' + (CASE WHEN si.[type] IN (5,6) THEN 'COLUMNSTORE ' ELSE ' ' END) +
N'INDEX ' + QUOTENAME(si.name) + N' ON ' + QUOTENAME(sc.name) + N'.' + QUOTENAME(t.name) + N' '
END +
/* key def */ (CASE WHEN si.[type] IN (0, 1, 2) THEN N'(' + [keys].[key_definition] + N') ' WHEN si.[type] = 6 THEN N'(' + [keys1].[key_definition] + N') ' ELSE '' END) +
/* includes */ (CASE WHEN si.[type] IN (0, 1, 2) THEN CASE WHEN [includes].[include_definition] IS NOT NULL THEN
N' INCLUDE (' + [includes].[include_definition] + N')'
ELSE N''
END ELSE '' END) +
/* filters */ CASE WHEN [si].[filter_definition] IS NOT NULL THEN
N' WHERE ' + [si].[filter_definition] ELSE N''
END +
/* with clause - compression goes here */
CASE WHEN [row_compression_clause].[row_compression_partition_list] IS NOT NULL OR [page_compression_clause].[page_compression_partition_list] IS NOT NULL
THEN N' WITH (' +
CASE WHEN [row_compression_clause].[row_compression_partition_list] IS NOT NULL THEN
N'DATA_COMPRESSION = ROW ' + CASE WHEN psc.name IS NULL THEN N'' ELSE + N' ON PARTITIONS (' + [row_compression_clause].[row_compression_partition_list] + N') ' END
ELSE N'' END +
CASE WHEN [page_compression_clause]. [page_compression_partition_list] IS NOT NULL THEN
N'DATA_COMPRESSION = PAGE ' + CASE WHEN psc.name IS NULL THEN N'' ELSE + N' ON PARTITIONS (' + [page_compression_clause]. [page_compression_partition_list] +
N')' END
ELSE N'' END
+ N')'
ELSE N''
END +
/* ON where? filegroup? partition scheme? */
' ON ' + CASE WHEN psc.name is null
THEN ISNULL(QUOTENAME(fg.name),N'')
ELSE psc.name + N' (' + [partitioning_column].[column_name] + N')'
END
+ N';'
END AS index_create_statement,
[partition_sums].[reserved_in_row_GB],
[partition_sums].[reserved_LOB_GB],
format([partition_sums].[row_count], 'N0') as row_count,
[stat].[user_seeks],
[stat].[user_scans],
[stat].[user_lookups],
[stat].[user_updates] AS queries_that_modified,
[partition_sums].[partition_count],
[si].[allow_page_locks],
[si].[allow_row_locks],
[si].[is_hypothetical],
[si].[has_filter],
[si].[fill_factor],
[si].[is_unique],
ISNULL(pf.name, '/* Not partitioned */') AS partition_function,
ISNULL(psc.name, fg.name) AS partition_scheme_or_filegroup,
t.create_date AS table_created_date,
t.modify_date AS table_modify_date
FROM
sys.indexes AS si
JOIN sys.tables AS t ON si.[object_id] = t.[object_id]
AND (t.name IN (SELECT TableName FROM @tbl) OR (SELECT COUNT(1) FROM @tbl) = 0)
JOIN sys.schemas AS sc ON t.[schema_id] = sc.[schema_id]
AND (@SchemaName is not null and t.schema_id = SCHEMA_ID(@SchemaName) or @SchemaName is null)
LEFT JOIN sys.dm_db_index_usage_stats AS stat ON [stat].[database_id] = DB_ID() AND si.[object_id] = stat.[object_id] AND si.index_id=stat.index_id
LEFT JOIN sys.partition_schemes AS psc ON si.data_space_id=psc.data_space_id
LEFT JOIN sys.partition_functions AS pf ON psc.function_id=pf.function_id
LEFT JOIN sys.filegroups AS fg ON si.data_space_id=fg.data_space_id

/* Key list */
OUTER APPLY (
SELECT STUFF ((
SELECT
N', ' + QUOTENAME([c].[name]) + CASE [ic].[is_descending_key] WHEN 1 THEN N' DESC' ELSE N'' END
FROM
sys.index_columns AS ic
JOIN
sys.columns AS c ON ic.column_id=c.column_id and ic.[object_id] = c.[object_id]
WHERE
ic.[object_id] = si.[object_id]
AND [ic].[index_id]=si.index_id
AND [ic].[key_ordinal] > 0
ORDER BY
[ic].[key_ordinal]
FOR
XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'),1,2,''
)
) AS keys ( key_definition )

/* Key list of nonclustered columnstore index */
OUTER APPLY (
SELECT STUFF((
SELECT N', ' + QUOTENAME(c.name)
FROM sys.index_columns ic
JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE ic.object_id = si.object_id 
AND ic.index_id = si.index_id
AND si.type = 6
AND c.name NOT IN
	(SELECT c1.name 
		FROM sys.indexes AS i1 
		JOIN sys.partition_schemes AS ps    
			ON ps.data_space_id = i1.data_space_id AND i1.[type] <= 1 
			AND i1.[object_id] = i.[object_id]    
		JOIN sys.index_columns AS ic    
		ON ic.[object_id] = i.[object_id] AND ic.index_id = i.index_id  AND ic.partition_ordinal >= 1
		JOIN sys.columns c1 ON ic.object_id = c.object_id AND ic.column_id = c.column_id
		where c1.name = c.name )     
ORDER BY ic.key_ordinal
FOR XML PATH(''), TYPE
).value('.', 'NVARCHAR(MAX)'), 1, 2, ''
)
FROM sys.indexes i
JOIN sys.tables t ON i.object_id = t.object_id
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE i.type = 6 -- 6 nonclustered columnstore index
AND i.object_id = si.object_id
AND i.index_id = si.index_id
) AS keys1 ( key_definition )

/* Partitioning Ordinal */
OUTER APPLY (
SELECT
MAX ( QUOTENAME ( [c] .[name]) ) AS column_name
FROM
sys.index_columns AS ic
JOIN sys.columns AS c ON ic.column_id=c.column_id and ic.[object_id]=c.[object_id]
WHERE
ic.[object_id] = si.[object_id]
AND [ic].[index_id]=si.index_id
AND [ic].[partition_ordinal] = 1
) AS partitioning_column

/* Include list */
OUTER APPLY (
SELECT STUFF ((
SELECT
N', ' + QUOTENAME([c].[name])
FROM
sys.index_columns AS ic
JOIN sys.columns AS c ON ic.column_id=c.column_id AND ic.[object_id]=c.[object_id]
WHERE
ic.[object_id] = si.[object_id]
AND [ic].[index_id]=si.index_id
AND [ic].[is_included_column] = 1
ORDER BY
[c] .[name]
FOR
XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'),1,2,''
)
) AS includes ( include_definition )

/* Partitions */
OUTER APPLY (
SELECT
COUNT(*) AS partition_count,
CAST(SUM([ps].[in_row_reserved_page_count])*8./1024./1024. AS NUMERIC(32,1)) AS reserved_in_row_GB,
CAST(SUM([ps].[lob_reserved_page_count])*8./1024./1024. AS NUMERIC(32,1)) AS reserved_LOB_GB,
SUM([ps].[row_count]) AS row_count
FROM
sys.partitions AS p
JOIN sys.dm_db_partition_stats AS ps ON p.[partition_id]=ps.[partition_id]
WHERE
p.[object_id] = si.[object_id]
AND p.index_id=si.index_id
) AS partition_sums

/* row compression list by partition */
OUTER APPLY (
SELECT STUFF ((
SELECT
N', ' + CAST([p].[partition_number] AS VARCHAR(32))
FROM
sys.partitions AS p
WHERE
[p].[object_id] = si.[object_id]
AND [p].[index_id]=si.index_id
AND [p].[data_compression] = 1 -- row compression
ORDER BY
[p].[partition_number]
FOR
XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'),1,2,''
)
) AS row_compression_clause ( row_compression_partition_list )

/* data compression list by partition */
OUTER APPLY (
SELECT STUFF ((
SELECT
N', ' + CAST([p].[partition_number] AS VARCHAR(32))
FROM
sys.partitions AS p
WHERE
[p].[object_id] = si.[object_id]
AND [p].[index_id]=si.index_id
AND [p].[data_compression] = 2 -- page compression
ORDER BY
[p].[partition_number]
FOR
XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'),1,2,''
)
) AS page_compression_clause ( page_compression_partition_list )
WHERE
si.type IN (0,1,2,4,5,6) /* heap, clustered, nonclustered */
ORDER BY
table_name, si.index_id
OPTION (RECOMPILE);
GO
