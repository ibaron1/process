DECLARE @PageSize INT = 500;
DECLARE @PageNumber INT = 3;

SELECT *
FROM dbo.fn_GetRiskValuesRaw()
ORDER BY asof_dt DESC
OFFSET (@PageNumber - 1) * @PageSize ROWS
FETCH NEXT @PageSize ROWS ONLY;

--Use this when user/UI specifies a page — very fast and scalable.
