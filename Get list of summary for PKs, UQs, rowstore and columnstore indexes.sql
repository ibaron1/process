WITH IndexBase AS (
    SELECT
        t.object_id AS TableObjectID,
        t.name AS TableName,
        s.name AS SchemaName,
        i.name AS IndexName,
        i.index_id,
        i.type_desc AS IndexType,
        i.is_primary_key,
        i.is_unique_constraint,
        i.is_unique,
        i.has_filter,
        i.filter_definition,
        ds.name AS DataSpaceName,
        ps.name AS PartitionScheme,
        partcol.name AS PartitionColumn
    FROM sys.tables t
    JOIN sys.schemas s ON s.schema_id = t.schema_id
    JOIN sys.indexes i ON i.object_id = t.object_id
    LEFT JOIN sys.data_spaces ds ON ds.data_space_id = i.data_space_id
    LEFT JOIN sys.partition_schemes ps ON ps.data_space_id = ds.data_space_id
    LEFT JOIN sys.index_columns icp 
        ON icp.object_id = i.object_id AND icp.index_id = i.index_id AND icp.partition_ordinal = 1
    LEFT JOIN sys.columns partcol 
        ON partcol.object_id = t.object_id AND partcol.column_id = icp.column_id
    WHERE t.is_ms_shipped = 0 AND i.is_hypothetical = 0
),
KeyCols AS (
    SELECT 
        ic.object_id,
        ic.index_id,
        STRING_AGG(
            CAST(
                QUOTENAME(c.name COLLATE DATABASE_DEFAULT) + 
                CASE WHEN ic.is_descending_key = 1 THEN ' DESC' ELSE ' ASC' END 
            AS NVARCHAR(MAX)), ', '
        ) WITHIN GROUP (ORDER BY ic.key_ordinal) AS KeyColumns
    FROM sys.index_columns ic
    JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
    WHERE ic.key_ordinal > 0
    GROUP BY ic.object_id, ic.index_id
),
IncludedCols AS (
    SELECT 
        ic.object_id,
        ic.index_id,
        STRING_AGG(CAST(QUOTENAME(c.name COLLATE DATABASE_DEFAULT) AS NVARCHAR(MAX)), ', ') AS IncludedColumns
    FROM sys.index_columns ic
    JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
    WHERE ic.is_included_column = 1
    GROUP BY ic.object_id, ic.index_id
),
ColumnstoreCols AS (
    SELECT 
        ic.object_id,
        ic.index_id,
        STRING_AGG(CAST(QUOTENAME(c.name COLLATE DATABASE_DEFAULT) AS NVARCHAR(MAX)), ', ') AS ColumnstoreColumns
    FROM sys.index_columns ic
    JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
    WHERE ic.key_ordinal = 0 AND ic.is_included_column = 0
    GROUP BY ic.object_id, ic.index_id
)
SELECT
    ib.SchemaName + '.' + ib.TableName AS [Schema.Table],
    CASE 
        WHEN ib.is_primary_key = 1 THEN 'PRIMARY KEY'
        WHEN ib.is_unique_constraint = 1 THEN 'UNIQUE CONSTRAINT'
        ELSE ib.IndexType
    END AS ObjectType,

    -- DROP Statement
    ISNULL(
        CASE 
            WHEN ib.is_primary_key = 1 OR ib.is_unique_constraint = 1 THEN 
                'IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N''' + 
                    QUOTENAME(ib.SchemaName) + '.' + QUOTENAME(ib.IndexName) + 
                    ''') AND type IN (''PK'', ''UQ''))' + CHAR(13) +
                '    ALTER TABLE [' + ib.SchemaName + '].[' + ib.TableName + '] DROP CONSTRAINT [' + ib.IndexName + ']'
            ELSE 
                'IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = N''' + ib.IndexName + ''' AND object_id = OBJECT_ID(N''' + 
                    ib.SchemaName + '.' + ib.TableName + 
                    '''))' + CHAR(13) +
                '    DROP INDEX [' + ib.IndexName + '] ON [' + ib.SchemaName + '].[' + ib.TableName + ']'
        END,
        '-- Could not generate DROP statement'
    ) AS DropStatement,

    -- CREATE Statement
    ISNULL(
        CASE 
            WHEN ib.is_primary_key = 1 THEN
                'IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N''' + ib.IndexName + ''')' + CHAR(13) +
                '    ALTER TABLE [' + ib.SchemaName + '].[' + ib.TableName + '] ADD CONSTRAINT [' + ib.IndexName + '] PRIMARY KEY ' + ib.IndexType +
                ' (' + ISNULL(kc.KeyColumns, '') + ')' +
                CASE 
                    WHEN ib.PartitionScheme IS NOT NULL AND ib.PartitionColumn IS NOT NULL 
                        THEN ' ON [' + ib.PartitionScheme + ']([' + ib.PartitionColumn + '])'
                    WHEN ib.DataSpaceName IS NOT NULL 
                        THEN ' ON [' + ib.DataSpaceName + ']'
                    ELSE ''
                END

            WHEN ib.is_unique_constraint = 1 THEN
                'IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N''' + ib.IndexName + ''')' + CHAR(13) +
                '    ALTER TABLE [' + ib.SchemaName + '].[' + ib.TableName + '] ADD CONSTRAINT [' + ib.IndexName + '] UNIQUE ' + ib.IndexType +
                ' (' + ISNULL(kc.KeyColumns, '') + ')' +
                CASE 
                    WHEN ib.PartitionScheme IS NOT NULL AND ib.PartitionColumn IS NOT NULL 
                        THEN ' ON [' + ib.PartitionScheme + ']([' + ib.PartitionColumn + '])'
                    WHEN ib.DataSpaceName IS NOT NULL 
                        THEN ' ON [' + ib.DataSpaceName + ']'
                    ELSE ''
                END

            WHEN ib.IndexType = 'NONCLUSTERED COLUMNSTORE' THEN
                'IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N''' + ib.IndexName + ''' AND object_id = OBJECT_ID(N''' + 
                    ib.SchemaName + '.' + ib.TableName + 
                    '''))' + CHAR(13) +
                '    CREATE NONCLUSTERED COLUMNSTORE INDEX [' + ib.IndexName + '] ON [' + ib.SchemaName + '].[' + ib.TableName + ']' +
                CASE 
                    WHEN cci.ColumnstoreColumns IS NOT NULL 
                        THEN ' (' + cci.ColumnstoreColumns + ')' 
                    ELSE '' 
                END +
                CASE 
                    WHEN ib.PartitionScheme IS NOT NULL AND ib.PartitionColumn IS NOT NULL 
                        THEN ' ON [' + ib.PartitionScheme + ']([' + ib.PartitionColumn + '])'
                    WHEN ib.DataSpaceName IS NOT NULL 
                        THEN ' ON [' + ib.DataSpaceName + ']'
                    ELSE ''
                END

            WHEN kc.KeyColumns IS NOT NULL THEN
                'IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N''' + ib.IndexName + ''' AND object_id = OBJECT_ID(N''' + 
                    ib.SchemaName + '.' + ib.TableName + 
                    '''))' + CHAR(13) +
                '    CREATE ' +
                CASE WHEN ib.is_unique = 1 THEN 'UNIQUE ' ELSE '' END +
                ib.IndexType + ' INDEX [' + ib.IndexName + '] ON [' + ib.SchemaName + '].[' + ib.TableName + '] (' + kc.KeyColumns + ')' +
                CASE WHEN inc.IncludedColumns IS NOT NULL THEN ' INCLUDE (' + inc.IncludedColumns + ')' ELSE '' END +
                CASE WHEN ib.has_filter = 1 THEN ' WHERE ' + ib.filter_definition ELSE '' END +
                CASE 
                    WHEN ib.PartitionScheme IS NOT NULL AND ib.PartitionColumn IS NOT NULL 
                        THEN ' ON [' + ib.PartitionScheme + ']([' + ib.PartitionColumn + '])'
                    WHEN ib.DataSpaceName IS NOT NULL 
                        THEN ' ON [' + ib.DataSpaceName + ']'
                    ELSE ''
                END

            ELSE '-- Could not generate CREATE INDEX: No key columns or unhandled type'
        END,
        '-- Could not generate CREATE statement'
    ) AS CreateStatement

FROM IndexBase ib
LEFT JOIN KeyCols kc ON kc.object_id = ib.TableObjectID AND kc.index_id = ib.index_id
LEFT JOIN IncludedCols inc ON inc.object_id = ib.TableObjectID AND inc.index_id = ib.index_id
LEFT JOIN ColumnstoreCols cci ON cci.object_id = ib.TableObjectID AND cci.index_id = ib.index_id
ORDER BY ib.SchemaName, ib.TableName, ib.IndexName;
