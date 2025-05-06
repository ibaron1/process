-- Step 1: Get all users and their roles (including inherited roles)
;WITH CTE_Roles AS (
    SELECT drm.member_principal_id, drm.role_principal_id
    FROM sys.database_role_members drm
    UNION ALL
    SELECT drm.member_principal_id, drm.role_principal_id
    FROM sys.database_role_members drm
    INNER JOIN CTE_Roles cr ON drm.member_principal_id = cr.role_principal_id
),
-- Get user-role combinations
UserRolePairs AS (
    SELECT 
        dp_member.name AS UserName,
        dp_role.name AS RoleName
    FROM CTE_Roles cr
    JOIN sys.database_principals dp_member ON cr.member_principal_id = dp_member.principal_id
    JOIN sys.database_principals dp_role ON cr.role_principal_id = dp_role.principal_id
),
-- Deduplicate role pairs before aggregation
DistinctUserRoles AS (
    SELECT DISTINCT UserName, RoleName
    FROM UserRolePairs
),
-- Aggregate roles per user
AggregatedRoles AS (
    SELECT 
        UserName,
        STRING_AGG(RoleName, ', ') AS Roles
    FROM DistinctUserRoles
    GROUP BY UserName
),
-- Gather distinct user-permission-schema combinations
DistinctPermissions AS (
    SELECT DISTINCT
        dp.name AS UserName,
        perm.permission_name,
        OBJECT_SCHEMA_NAME(perm.major_id) AS SchemaName
    FROM sys.database_permissions perm
    JOIN sys.database_principals dp ON perm.grantee_principal_id = dp.principal_id
    WHERE perm.class IN (1, 3)
),
-- Aggregate permissions per user + schema
AggregatedPermissions AS (
    SELECT 
        UserName,
        SchemaName,
        STRING_AGG(permission_name, ', ') AS Permissions
    FROM DistinctPermissions
    GROUP BY UserName, SchemaName
)

-- Final result with header row and blanks instead of NULLs
SELECT 
    'SQL Server: ' + @@SERVERNAME + 
    ' | Database: ' + DB_NAME() + 
    ' | Scan Time: ' + CONVERT(varchar, GETDATE(), 120) AS Info,
    '' AS UserName,
    '' AS Roles,
    '' AS SchemaName,
    '' AS Permissions

UNION ALL

SELECT 
    '' AS Info,
    ISNULL(p.UserName, '') AS UserName,
    ISNULL(r.Roles, '') AS Roles,
    ISNULL(p.SchemaName, '') AS SchemaName,
    ISNULL(p.Permissions, '') AS Permissions
FROM AggregatedPermissions p
LEFT JOIN AggregatedRoles r ON p.UserName = r.UserName
ORDER BY UserName, SchemaName;
