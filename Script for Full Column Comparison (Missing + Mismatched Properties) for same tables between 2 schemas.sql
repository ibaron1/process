WITH abc_cols AS (
    SELECT * 
    FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_SCHEMA = 'abc'
),
dbo_cols AS (
    SELECT * 
    FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_SCHEMA = 'dbo'
),
abc_tables AS (
    SELECT DISTINCT TABLE_NAME 
    FROM abc_cols
)

-- Columns present in abc, matched or missing in dbo
SELECT 
    a.TABLE_NAME AS table_name,
    a.COLUMN_NAME AS column_name,

    CASE 
        WHEN d.COLUMN_NAME IS NULL THEN 'Missing in dbo'
        WHEN a.DATA_TYPE <> d.DATA_TYPE
          OR CAST(ISNULL(a.CHARACTER_MAXIMUM_LENGTH, 0) AS INT) <> CAST(ISNULL(d.CHARACTER_MAXIMUM_LENGTH, 0) AS INT)
          OR CAST(ISNULL(a.NUMERIC_PRECISION, 0) AS INT) <> CAST(ISNULL(d.NUMERIC_PRECISION, 0) AS INT)
          OR CAST(ISNULL(a.NUMERIC_SCALE, 0) AS INT) <> CAST(ISNULL(d.NUMERIC_SCALE, 0) AS INT)
          OR a.IS_NULLABLE <> d.IS_NULLABLE
        THEN 'Property mismatch'
        ELSE NULL
    END AS issue_type,

    d.DATA_TYPE AS dbo_data_type,
    d.CHARACTER_MAXIMUM_LENGTH AS dbo_max_length,
    d.NUMERIC_PRECISION AS dbo_precision,
    d.NUMERIC_SCALE AS dbo_scale,
    d.IS_NULLABLE AS dbo_nullable,

    a.DATA_TYPE AS abc_data_type,
    a.CHARACTER_MAXIMUM_LENGTH AS abc_max_length,
    a.NUMERIC_PRECISION AS abc_precision,
    a.NUMERIC_SCALE AS abc_scale,
    a.IS_NULLABLE AS abc_nullable

FROM abc_cols a
LEFT JOIN dbo_cols d
    ON d.TABLE_NAME = a.TABLE_NAME
    AND d.COLUMN_NAME = a.COLUMN_NAME
WHERE a.TABLE_NAME IN (SELECT TABLE_NAME FROM abc_tables)
AND (
    d.COLUMN_NAME IS NULL
    OR a.DATA_TYPE <> d.DATA_TYPE
    OR CAST(ISNULL(a.CHARACTER_MAXIMUM_LENGTH, 0) AS INT) <> CAST(ISNULL(d.CHARACTER_MAXIMUM_LENGTH, 0) AS INT)
    OR CAST(ISNULL(a.NUMERIC_PRECISION, 0) AS INT) <> CAST(ISNULL(d.NUMERIC_PRECISION, 0) AS INT)
    OR CAST(ISNULL(a.NUMERIC_SCALE, 0) AS INT) <> CAST(ISNULL(d.NUMERIC_SCALE, 0) AS INT)
    OR a.IS_NULLABLE <> d.IS_NULLABLE
)

UNION ALL

-- Columns present in dbo but missing in abc (only for tables in abc schema)
SELECT 
    d.TABLE_NAME AS table_name,
    d.COLUMN_NAME AS column_name,
    'Missing in abc' AS issue_type,

    d.DATA_TYPE AS dbo_data_type,
    d.CHARACTER_MAXIMUM_LENGTH AS dbo_max_length,
    d.NUMERIC_PRECISION AS dbo_precision,
    d.NUMERIC_SCALE AS dbo_scale,
    d.IS_NULLABLE AS dbo_nullable,

    NULL AS abc_data_type,
    NULL AS abc_max_length,
    NULL AS abc_precision,
    NULL AS abc_scale,
    NULL AS abc_nullable

FROM dbo_cols d
WHERE d.TABLE_NAME IN (SELECT TABLE_NAME FROM abc_tables)
AND NOT EXISTS (
    SELECT 1 FROM abc_cols a
    WHERE a.TABLE_NAME = d.TABLE_NAME
    AND a.COLUMN_NAME = d.COLUMN_NAME
)

ORDER BY table_name, column_name;
