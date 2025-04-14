WITH IndexColumns AS (
    SELECT
        OBJECT_NAME(i.object_id) AS TableName,
        i.name AS IndexName,
        i.object_id,
        i.index_id,
        ic.index_column_id,
        COL_NAME(ic.object_id, ic.column_id) AS ColumnName,
        ic.is_included_column,
        ic.is_descending_key
    FROM
        sys.indexes i
    JOIN
        sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
    WHERE
        i.is_primary_key = 0 AND
        i.is_unique_constraint = 0 AND
        i.type_desc <> 'HEAP'
),
IndexDefinitions AS (
    SELECT
        object_id,
        index_id,
        TableName,
        IndexName,
        -- Create a string representing key columns with order (ignoring included columns)
        STRING_AGG(
            CASE 
                WHEN is_included_column = 0 THEN 
                    ColumnName + CASE WHEN is_descending_key = 1 THEN ' DESC' ELSE ' ASC' END 
                ELSE NULL 
            END,
            ','
        ) WITHIN GROUP (ORDER BY index_column_id) AS KeyDefinition
    FROM
        IndexColumns
    WHERE
        is_included_column = 0
    GROUP BY
        object_id, index_id, TableName, IndexName
),
DuplicateIndexes AS (
    SELECT 
        a.TableName,
        a.KeyDefinition,
        COUNT(*) AS DuplicateCount,
        STRING_AGG(a.IndexName, ', ') AS IndexNames
    FROM
        IndexDefinitions a
    GROUP BY
        a.TableName,
        a.KeyDefinition
    HAVING 
        COUNT(*) > 1
)
SELECT 
    TableName,
    KeyDefinition,
    DuplicateCount,
    IndexNames
FROM 
    DuplicateIndexes
ORDER BY 
    TableName;
