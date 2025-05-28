CREATE TABLE DataMart_log.MissingOrIncorrectEtlStageColumns
(EtlStageTable VARCHAR(900) NOT NULL CONSTRAINT PK_MissingOrIncorrectEtlStageColumns PRIMARY KEY CLUSTERED,
NotDefinedColumnNameFromEtlStage VARCHAR(MAX) NULL,
[Missing DevOps.Sentry360_2.0 Title/Column] VARCHAR(MAX) NULL,
ProcessedDate datetime NOT NULL,
ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START,
ValidTo DATETIME2 GENERATED ALWAYS AS ROW END,
PERIOD FOR SYSTEM_TIME(ValidFrom, ValidTo)
)
WITH (SYSTEM_VERSIONING = ON
(HISTORY_TABLE = DataMart_Log.MissingOrIncorrectEtlStageColumns_History,
HISTORY_RETENTION_PERIOD = 2 WEEKS)
);
GO

/*
-- DROP temporal TABLE
ALTER TABLE DataMart_Log.MissingOrIncorrectEtlStageColumns SET ( SYSTEM_VERSIONING = OFF )
GO
DROP TABLE DataMart_Log.MissingOrIncorrectEtlStageColumns
GO
DROP TABLE DataMart_Log.MissingOrIncorrectEtlStageColumns_History
*/