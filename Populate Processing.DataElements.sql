SET NOCOUNT ON

DECLARE @tbl VARCHAR(MAX)
,@tblName varchar(200)='CorporateAdvanceTransactions' -- null -- > must be in loop for all tables
,@schema varchar(100)='DataMart'

drop table if exists #t;
select TABLE_NAME as TableName, COLUMN_NAME as ColumnName, NULL as PrimaryKeyIndex,
		concat(DATA_TYPE
			, CASE	WHEN DATA_TYPE NOT LIKE '%int'
					THEN CONCAT(IIF(CHARACTER_MAXIMUM_LENGTH IS NULL, '', '('+CAST(CHARACTER_MAXIMUM_LENGTH AS VARCHAR(100))+')')
							,IIF(NUMERIC_PRECISION IS NULL, '', '('+CAST(NUMERIC_PRECISION AS VARCHAR(100))+','+CAST(NUMERIC_SCALE AS VARCHAR(2))+')'))
			  END)		as Datatype,
		ORDINAL_POSITION-3 as OrdinalPosition
into #t
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA=@schema and TABLE_NAME = @tblName
and COLUMN_NAME not in ('RowHash','RecordStartDate','RecordEndDate')

--select * from #t
	update  #t set PrimaryKeyIndex=1 where ColumnName='LoanNumber';
	update  #t set PrimaryKeyIndex=2 where ColumnName='CorporateAdvanceTransactionsId';
select * from #t
/*
insert Processing.DataElements
select * from #t
*/