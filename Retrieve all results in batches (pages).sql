--simulate pagination — not limit rows, but instead retrieve all results in batches (pages)
-- 1. Initialize: drop & recreate temp table
IF OBJECT_ID('tempdb..#PagedResults') IS NOT NULL DROP TABLE #PagedResults;

-- Create structure by querying 0 rows from the TVF
SELECT TOP 0 *
INTO #PagedResults
FROM dbo.fn_GetRiskValuesRaw();

-- 2. Pagination variables
DECLARE @PageSize INT = 500;
DECLARE @PageNumber INT = 1;
DECLARE @TotalRows INT;
DECLARE @TotalPages INT;

-- 3. Get total row count
SELECT @TotalRows = COUNT(*) FROM dbo.fn_GetRiskValuesRaw();
SET @TotalPages = CEILING(1.0 * @TotalRows / @PageSize);

-- 4. Loop through pages and insert each batch into temp table
WHILE @PageNumber <= @TotalPages
BEGIN
    INSERT INTO #PagedResults
    SELECT *
    FROM dbo.fn_GetRiskValuesRaw()
    ORDER BY asof_dt DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;

    PRINT CONCAT('Fetched page ', @PageNumber, ' of ', @TotalPages);
    SET @PageNumber += 1;
END

-- 5. Return full result set
SELECT *
FROM #PagedResults
ORDER BY asof_dt DESC;
