/*
💡 Summary Table
Feature	Supported in Tableau?
Call stored procedure	✅ (limited, SQL Server)
Stored proc with parameters	⚠️ (not directly)
Used in extract	❌ Not supported
Returns scalar or messages	❌ Not supported
View or TVF workaround	✅ Recommended

Yes, a Table-Valued Function (TVF) in SQL Server can use pagination, but with important caveats, especially depending on whether you're using:

Inline TVFs (preferred by Tableau)

Multi-statement TVFs (less performant)

✅ Inline TVF with Pagination (Recommended)
You can use OFFSET–FETCH NEXT in an inline TVF starting from SQL Server 2012+:

✅ Best Practice for Tableau Integration
If you're using TVFs for pagination in Tableau:

Stick with inline TVFs

Use parameters in Tableau to control page number and size

Use ORDER BY carefully — required for OFFSET/FETCH
*/

CREATE FUNCTION dbo.fn_PaginatedData
(
    @PageNumber INT,
    @PageSize INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT *
    FROM YourBigTable
    ORDER BY SomeColumn
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY
);

/*
Then you must query it like:
SELECT * FROM dbo.fn_PaginatedData(1, 100); -- Page 1
SELECT * FROM dbo.fn_PaginatedData(2, 100); -- Page 2
...
You or application (e.g., Tableau, Power BI, .NET app) must loop through pages manually.
*/

--✅ TVF to return total rows and total pages

CREATE FUNCTION dbo.fn_PaginationInfo
(
    @PageSize INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        COUNT(*) AS TotalRows,
        CEILING(CAST(COUNT(*) AS FLOAT) / @PageSize) AS TotalPages
    FROM YourBigTable
);

/*
How to combine with your paginated TVF?
Call your paginated TVF to get data for a page.
Call fn_PaginationInfo once to get total pages and rows.
Client (Tableau or app) shows both results.
*/

/*
Key Notes:

This is a true inline TVF (good for performance and can be used in Tableau).

You must provide a deterministic ORDER BY column.

Can be used in Tableau via custom SQL like:

SELECT * FROM dbo.fn_PaginatedData(1, 100)
*/

/*
⚠️ Multi-Statement TVFs: Avoid If Possible

CREATE FUNCTION dbo.fn_BadPaginatedData
(
    @PageNumber INT,
    @PageSize INT
)
RETURNS @Result TABLE (...)
AS
BEGIN
    INSERT INTO @Result
    SELECT ...
    FROM ...
    ORDER BY ...
    OFFSET ...
    FETCH NEXT ...

    RETURN
END

Drawbacks:

No statistics, poor performance
Not usable in Tableau directly
Harder to optimize and troubleshoot
*/

