USE [ServiceMac]
GO
CREATE OR ALTER PROCEDURE Processing.Import_DataMartTablesFromEtlStage @TableName VARCHAR(200) = NULL
AS
SET NOCOUNT ON;

DECLARE @StartTime DATETIME = CURRENT_TIMESTAMP;
DECLARE @RowHash VARCHAR (MAX);

DELETE DataMart_Log.Import_DataMartTablesFromEtlStage_Log;
DELETE DataMart_Log.MissingOrIncorrectEtlStageColumns;

DECLARE @EtlStageTables TABLE (EtlStageTable VARCHAR(4000), ImportTable# INT);
DECLARE @EtlStageTable VARCHAR(200);
DECLARE @SQLStr VARCHAR(MAX);
DECLARE @EffectiveDate DATE;
DECLARE @DMTableName VARCHAR(200);
DECLARE @TableDefinition VARCHAR(MAX);

INSERT @EtlStageTables
SELECT T.TABLE_NAME
,ROW_NUMBER() OVER (ORDER BY T.TABLE_NAME) AS ImportTable#
FROM INFORMATION_SCHEMA.TABLES AS T
WHERE T.TABLE_SCHEMA = 'EtlStage'
AND (T.TABLE_NAME = @TableName OR @TableName IS NULL)
AND EXISTS (SELECT 1 FROM Processing.DataElements WHERE TableName = T.TABLE_NAME);

DECLARE @import TABLE
(ColumnName VARCHAR(4000) NULL
, DataType VARCHAR(100) NULL
, PrimaryKeyIndex TINYINT NULL
, OrdinalPosition INT NULL);

/* Drop DataMart tables before before refresh from EtlStage tables */
DECLARE @DropTableSQL VARCHAR(MAX);

SELECT @EffectiveDate = ED.EffectiveDate
FROM EtlStage.EffectiveDates AS ED 

DECLARE @ImportTable# INT = 1;

/* EtlStage tables Data Validation Report */
DECLARE @MissingOrIncorrectColumns TABLE
(EtlStageTable VARCHAR(4000) NOT NULL
, NotDefinedColumnNameFromEtlStage VARCHAR(MAX) NULL
, [Missing DevOps.Sentry360_2.0 Title/Column] VARCHAR(MAX) NULL
, ProcessedDate DATETIME NOT NULL);

WHILE @ImportTable# <= (SELECT MAX(ImportTable#) FROM @EtlStageTables)
BEGIN

	SELECT @EtlStageTable = EtlStageTable
	FROM @EtlStageTables
	WHERE ImportTable# = @ImportTable#;

	DELETE @import;

	INSERT @import
	SELECT DISTINCT
	  DE.ColumnName
	, DE.DataType
	, DE.PrimaryKeyIndex
	, DE.OrdinalPosition
	FROM Processing.DataElements AS DE
	INNER JOIN INFORMATION_SCHEMA.TABLES AS T ON
		DE.TableName = T.TABLE_NAME
	INNER JOIN INFORMATION_SCHEMA.COLUMNS AS C ON
		T.TABLE_SCHEMA = C.TABLE_SCHEMA
		AND T.TABLE_NAME = C.TABLE_NAME
		AND DE.ColumnName = C.COLUMN_NAME
	WHERE T.TABLE_TYPE = 'BASE TABLE'
		AND T.TABLE_NAME = @EtlStageTable
		AND T.TABLE_SCHEMA = 'EtlStage'
		AND DE.TableName NOT LIKE '%(Derived)%'
		AND DE.ColumnName NOT IN ( 'RecordStartDate', 'RecordEndDate' );

	-- Get columns from an uploaded Staging table not defined in DataMart DevOps
	INSERT DataMart_Log.MissingOrIncorrectEtlStageColumns (EtlStageTable, NotDefinedColumnNameFromEtlStage, ProcessedDate)
	SELECT @EtlStageTable
	, STRING_AGG(CAST(C.COLUMN_NAME AS VARCHAR(MAX)), ', ')
	, CURRENT_TIMESTAMP
	FROM INFORMATION_SCHEMA.TABLES AS T
	JOIN INFORMATION_SCHEMA.COLUMNS AS C ON
	T.TABLE_SCHEMA = C.TABLE_SCHEMA
	AND T.TABLE_NAME = C.TABLE_NAME
	AND T.TABLE_TYPE = 'BASE TABLE'
	AND T.TABLE_NAME = @EtlStageTable
	AND T.TABLE_SCHEMA = 'EtlStage'
	AND C.COLUMN_NAME NOT IN ( 'RecordStartDate', 'RecordEndDate' )
	WHERE NOT EXISTS
	(SELECT 1 FROM Processing.DataElements AS DE WHERE DE.TableName = T.TABLE_NAME AND DE.ColumnName = C.COLUMN_NAME);

	-- Missing columns as defined in DataMart DevOps table's schema
	;WITH CTE AS
		(SELECT STRING_AGG(CAST(DE.ColumnName AS VARCHAR(MAX)), ',') AS ColumnName
		 FROM Processing.DataElements AS DE
		 WHERE DE.TableName = @EtlStageTable
		 AND DE.ColumnName NOT IN ( 'RecordStartDate', 'RecordEndDate' )
		 AND NOT EXISTS
			(SELECT '1'
			FROM INFORMATION_SCHEMA.TABLES AS T
			INNER JOIN INFORMATION_SCHEMA.COLUMNS AS C ON
			T.TABLE_SCHEMA = C.TABLE_SCHEMA
			AND T.TABLE_NAME = C.TABLE_NAME
			AND DE.ColumnName = C.COLUMN_NAME
			AND T.TABLE_TYPE = 'BASE TABLE'
			AND T.TABLE_NAME = @EtlStageTable
			AND T.TABLE_SCHEMA = 'EtlStage' ))
		MERGE DataMart_Log.MissingOrIncorrectEtlStageColumns AS T
		USING
			(SELECT EtlStageTable
				 , CTE.ColumnName
			FROM @MissingOrIncorrectColumns
			CROSS JOIN CTE
			WHERE EtlStageTable = @EtlStageTable) AS S (EtlStageTable, Title)
		ON T.EtlStageTable = S.EtlStageTable
		WHEN MATCHED THEN
		UPDATE SET T.[Missing DevOps.Sentry360_2.0 Title/Column] = S.Title
		WHEN NOT MATCHED THEN
		INSERT (EtlStageTable, [Missing DevOps.Sentry360_2.0 Title/Column], ProcessedDate)
		VALUES
		(S.EtlStageTable, S.Title, CURRENT_TIMESTAMP);

	IF EXISTS (SELECT 1 FROM @import)
	BEGIN
	SET @DMTableName = CONCAT('DataMart.', @EtlStageTable);

	INSERT DataMart_Log.Import_DataMartTablesFromEtlStage_Log (TableName, StartTime)
	VALUES
	(@DMTableName, CURRENT_TIMESTAMP);

	BEGIN TRY

		SELECT @RowHash =
			CONCAT('CONVERT(BIGINT, HASHBYTES(''SHA1'',', CONCAT((SELECT STRING_AGG(CAST(CONCAT('CAST(ISNULL(',ColumnName,','''') AS VARCHAR(100))+'' |''') AS VARCHAR(MAX)) ,'+') ) ,') )' ) )
			FROM @import

		SET @SQLStr = CONCAT('
			DROP TABLE IF EXISTS DataMart.', @EtlStageTable, ';', CHAR(13), CHAR(13));

		SET @TableDefinition = CONCAT('SELECT ', @RowHash, ' AS RowHash,', CHAR(13));

		SET @TableDefinition += CONCAT(
									'NULLIF(CAST('''
									,@EffectiveDate
									,''' AS DATE), '''') AS RecordStartDate, CAST(NULL AS DATE) AS RecordEndDate, ');

		SELECT @TableDefinition += CONCAT(
										STRING_AGG(
											CAST(CASE WHEN PrimaryKeyIndex IS NOT NULL
											OR DataType = 'bit' -- nulliff(bit_0,'') incorrectly returns null instead of 0 though 0 is not null, found for data type bit
											THEN CAST (CONCAT(
													'ISNULL('
													, IIF(
													  DataType LIKE 'decimal%' OR DataType LIKE '%int'
													, 'TRY_CONVERT'
													, 'CONVERT' )
													, '('
													, DataType
													, ','
													, ColumnName
													, '),'
													, IIF(
													  DataType LIKE 'decimal%' OR DataType LIKE '%int'
														,'0', '''''')

													, ') AS '
													, ColumnName) AS VARCHAR (MAX) )
											ELSE
												CAST (CONCAT(
													'ISNULL('
													, IIF(
													  DataType LIKE 'decimal%' OR DataType LIKE '%int'
													, 'TRY_CONVERT'
													, 'CONVERT' )
													, '('
													, DataType
													, ','
													, ColumnName
													, '),'
													, IIF(
													  DataType LIKE 'decimal%' OR DataType LIKE '%int'
														,'0', '''''')

													, ') AS '
														, ColumnName) AS VARCHAR(MAX))
														END AS VARCHAR(MAX) )
														,',') WITHIN GROUP(ORDER BY OrdinalPosition)
														,' INTO DataMart.'
														, @EtlStageTable
														,' FROM EtlStage.'
														, @EtlStageTable
														, ';'
														, CHAR(13)
														, CHAR(13))
			FROM @import;

			-- create indexes
			SELECT @TableDefinition += CONCAT(
			'EXEC Processing.BuildTableIndexes_DataMart '''
			, @EtlStageTable
			, ''';'
			, CHAR(13)
			, CHAR(13));

			SELECT @SQLStr += @TableDefinition;

			EXEC (@SQLStr);

		END TRY
		BEGIN CATCH
			UPDATE DataMart_Log.Import_DataMartTablesFromEtLStage_Log
			SET Error = (SELECT ReturnedError FROM Processing.vw_ReturnedError)
			WHERE TableName = @DMTableName;
		END CATCH;

		UPDATE DataMart_Log.Import_DataMartTablesFromEtLStage_Log
		SET EndTime = CURRENT_TIMESTAMP
			,RunTime_sec = DATEDIFF(ss, StartTime, CURRENT_TIMESTAMP)
			,RunTime = Utilities.ParseTime(DATEDIFF(ss, StartTime, CURRENT_TIMESTAMP))
			,TableDefinition = @TableDefinition
		WHERE TableName = @DMTableName;
			
	END;

	SET @ImportTable# += 1;

END;

/* Create derived table and build indexes */
BEGIN
	INSERT DataMart_Log.Import_DataMartTablesFromEtlStage_Log (TableName, StartTime)
	VALUES
	('DataMart.BusinessFields', CURRENT_TIMESTAMP);

	BEGIN TRY
		EXEC Processing.Update_Derived_BusinessFields;
		EXEC Processing.BuildTableIndexes_DataMart_Derived;
	END TRY
	BEGIN CATCH
		UPDATE DataMart_Log.Import_DataMartTablesFromEtlStage_Log
		SET Error = (SELECT ReturnedError FROM Processing.vw_ReturnedError)
		WHERE TableName = 'DataMart.BusinessFields';
	END CATCH;

	UPDATE DataMart_Log.Import_DataMartTablesFromEtlStage_Log
	SET  EndTime = CURRENT_TIMESTAMP
	, RunTime_sec = DATEDIFF(ss, StartTime, CURRENT_TIMESTAMP)
	, RunTime = Utilities.ParseTime(DATEDIFF(ss, StartTime, CURRENT_TIMESTAMP) )
	WHERE TableName = 'DataMart.BusinessFields';
END;
GO


