-- Sets the isolation level to READ UNCOMMITTED
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
GO

-- Shows current session's isolation level
DBCC USEROPTIONS;
