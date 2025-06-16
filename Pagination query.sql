--https://www.sqlshack.com/pagination-in-sql-server/
--Pagination query in SQL Server
--After figuring out the answer to “What is Pagination?” question, we will learn how we can write a pagination query in SQL Server. At first, we will execute the following query and will tackle the query:

DECLARE @PageNumber AS INT
DECLARE @RowsOfPage AS INT
SET @PageNumber=2
SET @RowsOfPage=4
SELECT FruitName,Price FROM SampleFruits
ORDER BY Price 
OFFSET (@PageNumber-1)*@RowsOfPage ROWS
FETCH NEXT @RowsOfPage ROWS ONLY