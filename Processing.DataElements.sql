drop table if exists Processing.DataElements
go
CREATE table Processing.DataElements
(TableName varchar(200) not null,
 ColumnName varchar(200) not null,
 PrimaryKeyIndex int null,
 Datatype varchar(40) not null,
 OrdinalPosition int not null)
GO

create unique clustered index IX_DataElements_CI on Processing.DataElements(TableName,OrdinalPosition)