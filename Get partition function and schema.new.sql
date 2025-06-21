-- Partition Functions (corrected: use sys.partition_parameters to get data type)
SELECT 
    'CREATE PARTITION FUNCTION [' + pf.name + '](' + typ.name + 
    ') AS RANGE ' + 
    CASE pf.boundary_value_on_right WHEN 1 THEN 'RIGHT' ELSE 'LEFT' END +
    ' FOR VALUES (' + 
    STRING_AGG(CONVERT(NVARCHAR(MAX), prv.value), ', ') +
    ')' AS CreatePartitionFunction
FROM sys.partition_functions pf
JOIN sys.partition_parameters pp ON pf.function_id = pp.function_id
JOIN sys.types typ ON typ.user_type_id = pp.user_type_id
JOIN sys.partition_range_values prv ON prv.function_id = pf.function_id
GROUP BY pf.name, typ.name, pf.boundary_value_on_right;

-- Partition Schemes
SELECT 
    'CREATE PARTITION SCHEME [' + ps.name + '] AS PARTITION [' + pf.name + '] ALL TO ([PRIMARY])' AS CreatePartitionScheme
FROM sys.partition_schemes ps
JOIN sys.partition_functions pf ON pf.function_id = ps.function_id;
