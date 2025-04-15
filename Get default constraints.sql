--all constraints
SELECT 
    t.name AS Table_Name,
    c.name AS Column_Name,
    dc.name AS Default_Constraint_Name,
    dc.definition AS Default_Constraint_Definition
FROM 
    sys.tables t
INNER JOIN 
    sys.columns c ON t.object_id = c.object_id
INNER JOIN 
    sys.default_constraints dc ON c.default_object_id = dc.object_id
WHERE 
    t.is_ms_shipped = 0 -- Exclude system tables
ORDER BY 
    t.name, c.name;

--specific constraint
SELECT 
    t.name AS Table_Name,
    c.name AS Column_Name,
    dc.name AS Default_Constraint_Name,
    dc.definition AS Default_Constraint_Definition
FROM 
    sys.tables t
INNER JOIN 
    sys.columns c ON t.object_id = c.object_id
INNER JOIN 
    sys.default_constraints dc ON c.default_object_id = dc.object_id
WHERE t.name = 'Address' and c.name = 'ModifiedDate' and dc.name = 'DF_Address_ModifiedDate'

