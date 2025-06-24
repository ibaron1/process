
-- Materialize base result
SELECT *
INTO #RiskResultsTemp
FROM dbo.fn_GetRiskValuesRaw();

-- Apply pagination
SELECT *
FROM #RiskResultsTemp
ORDER BY asof_dt DESC
OFFSET (@PageNumber - 1) * @PageSize ROWS
FETCH NEXT @PageSize ROWS ONLY;
