--to remove blocking
SET NOCOUNT ON;
SET IMPLICIT_TRANSACTIONS OFF; 
-- TO BREAK IMPLICIT TRANSACTIONS, was Java default and can be from other languages/tools
--if Python driver “autocommit” setting is set to 'False' the session will have implicit_transactions ON
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

SET ANSI_WARNINGS OFF;
/*
When set to ON, if null values appear in aggregate functions, such as SUM, AVG, MAX, MIN, STDEV, STDEVP, VAR, VARP, or COUNT, 
a warning message is generated. When set to OFF, no warning is issued.
When set to ON, the divide-by-zero and arithmetic overflow errors cause the statement to be rolled back and an error message is generated. 
When set to OFF, the divide-by-zero and arithmetic overflow errors cause null values to be returned. 
*/