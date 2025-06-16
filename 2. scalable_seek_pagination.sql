-- =============================================
-- Scalable Pagination Framework for SQL Server
-- =============================================

-- 1. Cache Table to Store Row Counts
CREATE TABLE dbo.PaginationCache
(
    CacheKey NVARCHAR(100) PRIMARY KEY,
    TotalRows BIGINT NOT NULL,
    LastUpdated DATETIME NOT NULL DEFAULT GETDATE()
);

-- 2. Stored Procedure to Refresh Cache (supports filtering)
CREATE PROCEDURE dbo.sp_RefreshPaginationCache
    @CacheKey NVARCHAR(100),
    @SourceSQL NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SQL NVARCHAR(MAX) = '
        DECLARE @Count BIGINT;
        SELECT @Count = COUNT(*) FROM (' + @SourceSQL + ') AS T;

        MERGE dbo.PaginationCache AS target
        USING (SELECT ''' + @CacheKey + ''' AS CacheKey, @Count AS TotalRows) AS source
        ON target.CacheKey = source.CacheKey
        WHEN MATCHED THEN
            UPDATE SET TotalRows = source.TotalRows, LastUpdated = GETDATE()
        WHEN NOT MATCHED THEN
            INSERT (CacheKey, TotalRows, LastUpdated)
            VALUES (source.CacheKey, source.TotalRows, GETDATE());
    ';

    EXEC sp_executesql @SQL;
END;

-- 3. TVF to Get Cached Row Count and Page Count
CREATE FUNCTION dbo.fn_GetCachedPaginationInfo
(
    @PageSize INT,
    @CacheKey NVARCHAR(100)
)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        TotalRows,
        CEILING(CAST(TotalRows AS FLOAT) / @PageSize) AS TotalPages,
        LastUpdated
    FROM dbo.PaginationCache
    WHERE CacheKey = @CacheKey
);

-- 4. TVF for Seek-Based Pagination (with filter)
CREATE FUNCTION dbo.fn_SeekPaginatedData_Filtered
(
    @LastID INT = NULL,
    @PageSize INT = 100,
    @IsActive BIT = NULL
)
RETURNS TABLE
AS
RETURN
(
    SELECT TOP (@PageSize) *
    FROM YourBigTable
    WHERE 
        (@LastID IS NULL OR ID > @LastID)
        AND (@IsActive IS NULL OR IsActive = @IsActive)
    ORDER BY ID
);

-- 5. TVF for Seek Pagination with Composite Key (e.g. ID + Date)
CREATE FUNCTION dbo.fn_SeekPaginatedData_Composite
(
    @LastID INT = NULL,
    @LastDate DATETIME = NULL,
    @PageSize INT = 100
)
RETURNS TABLE
AS
RETURN
(
    SELECT TOP (@PageSize) *
    FROM YourBigTable
    WHERE 
        (
            @LastID IS NULL 
            OR (DateColumn > @LastDate)
            OR (DateColumn = @LastDate AND ID > @LastID)
        )
    ORDER BY DateColumn, ID
);

-- 6. TVF for Seek Pagination with GUID Key
CREATE FUNCTION dbo.fn_SeekPaginated_GUID
(
    @LastKey UNIQUEIDENTIFIER = NULL,
    @PageSize INT = 100
)
RETURNS TABLE
AS
RETURN
(
    SELECT TOP (@PageSize) *
    FROM YourBigTable
    WHERE (@LastKey IS NULL OR GuidKey > @LastKey)
    ORDER BY GuidKey
);

-- 7. View for Tableau to Query Page 1 with Fixed Filter
CREATE VIEW vw_YourBigTable_Page1
AS
SELECT *
FROM dbo.fn_SeekPaginatedData_Filtered(NULL, 100, 1);

-- 8. SQL Agent Job (example call for automation)
-- Use this in a SQL Agent Job Step:
--
-- EXEC dbo.sp_RefreshPaginationCache 
--     @CacheKey = 'YourBigTable:IsActive=1',
--     @SourceSQL = 'SELECT * FROM YourBigTable WHERE IsActive = 1';
