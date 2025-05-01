SET NOCOUNT ON

DECLARE @table_name SYSNAME, @table_name_to SYSNAME
DECLARE @handle_big_binary BIT
DECLARE @column_names BIT

-- ////////////////////
-- -> Configuration
SET @table_name = 'dbo.BookTable_Update_140422'
SET @table_name_to = 'srf_main.Book_Mapping_to_Region_Business'
SET @handle_big_binary = 1
SET @column_names = 1
-- <- Configuration
-- ////////////////////

DECLARE @object_id INT
DECLARE @schema_id INT

declare @sqlstr varchar(max)

--SELECT * FROM sys.all_objects
SELECT @object_id = object_id, @schema_id = schema_id 
   FROM sys.tables 
   WHERE object_id = OBJECT_ID(@table_name)


DECLARE @columns TABLE (column_name SYSNAME, ordinal_position INT, data_type SYSNAME, data_length INT, is_nullable BIT)

-- Get all column information
INSERT INTO @columns
   SELECT column_name, ordinal_position, data_type, character_maximum_length, CASE WHEN is_nullable = 'YES' THEN 1 ELSE 0 END
   FROM INFORMATION_SCHEMA.COLUMNS
   WHERE TABLE_SCHEMA = SCHEMA_NAME(@schema_id)
   AND TABLE_NAME = OBJECT_NAME(@object_id)

DECLARE @select VARCHAR(MAX)
DECLARE @insert VARCHAR(MAX)
DECLARE @crlf CHAR(2)
DECLARE @sql VARCHAR(MAX)
DECLARE @first BIT
DECLARE @pos INT
SET @pos = 1

SET @crlf = CHAR(13) + CHAR(10)

WHILE EXISTS (SELECT TOP 1 * FROM @columns WHERE ordinal_position >= @pos)
BEGIN
   DECLARE @column_name SYSNAME
   DECLARE @data_type SYSNAME
   DECLARE @data_length INT
   DECLARE @is_nullable BIT

   -- Get information for the current column
   SELECT @column_name = column_name, @data_type = data_type, @data_length = data_length, @is_nullable = is_nullable
      FROM @columns
      WHERE ordinal_position = @pos

   -- Create column select information to script the name of the source/destination column if configured
   IF (@select IS NULL)
      SET @select = ' ''' + QUOTENAME(@column_name)
   ELSE
      SET @select = @select + ','' + ' + @crlf + ' ''' + QUOTENAME(@column_name)

   -- Handle NULL values
   SET @sql = ' '
   --SET @sql = @sql+'CASE WHEN '+QUOTENAME(@column_name)+' IS NULL OR '+QUOTENAME(rtrim(@column_name))+' = ''NULL'' THEN ''NULL'' ELSE '
   SET @sql = @sql+'CASE WHEN '+QUOTENAME(@column_name)+' IS NULL OR '+QUOTENAME(@column_name)+' like ''NULL%'' THEN ''NULL'' ELSE '

   -- Handle the different data types
   IF (@data_type IN ('bigint', 'bit', 'decimal', 'float', 'int', 'money', 'numeric',
 'real', 'smallint', 'smallmoney', 'tinyint','geography','time'))
   BEGIN
      SET @sql = @sql + 'CONVERT(VARCHAR(max), ' + QUOTENAME(@column_name) + ')'
   END
   ELSE IF (@data_type IN ('char', 'nchar', 'nvarchar', 'varchar', 'datetime', 'date'))
   BEGIN
      SET @sql = @sql + ''''''''' + REPLACE(' + QUOTENAME(@column_name) + ', '''''''', '''''''''''') + '''''''''
   END
   ELSE IF (@data_type = 'date')
   BEGIN
      SET @sql = @sql + '''CONVERT(DATE, '' + master.sys.fn_varbintohexstr (CONVERT(BINARY(3), ' + QUOTENAME(@column_name) + ')) + '')'''
   END
   ELSE IF (@data_type = 'datetime')
   BEGIN
      SET @sql = @sql + '''CONVERT(DATE, '' + master.sys.fn_varbintohexstr (CONVERT(BINARY(3), ' + QUOTENAME(@column_name) + ')) + '')'''
   END
   -- ELSE IF (@data_type = 'time')
   --BEGIN
   --   SET @sql = @sql + '''CONVERT(DATE, '' + master.sys.fn_varbintohexstr (CONVERT(BINARY(3), ' + QUOTENAME(@column_name) + ')) + '')'''
   --END
    ELSE IF (@data_type = 'geography')
   BEGIN
      SET @sql = @sql + '''CONVERT(GEOGRAPHY, '' + master.sys.fn_varbintohexstr (CONVERT(BINARY(5), ' + QUOTENAME(@column_name) + ')) + '')'''
   END
   ELSE IF (@data_type = 'time')
   BEGIN
      SET @sql = @sql + '''CONVERT(TIME, '' + master.sys.fn_varbintohexstr (CONVERT(BINARY(5), ' + QUOTENAME(@column_name) + ')) + '')'''
   END
   ELSE IF (@data_type = 'datetime')
   BEGIN
      SET @sql = @sql + '''CONVERT(DATETIME, '' + master.sys.fn_varbintohexstr (CONVERT(BINARY(8), ' + QUOTENAME(@column_name) + ')) + '')'''
   END
   ELSE IF (@data_type = 'datetime2')
   BEGIN
      SET @sql = @sql + '''CONVERT(DATETIME2, '' + master.sys.fn_varbintohexstr (CONVERT(BINARY(8), ' + QUOTENAME(@column_name) + ')) + '')'''
   END
   ELSE IF (@data_type = 'smalldatetime')
   BEGIN
      SET @sql = @sql + '''CONVERT(SMALLDATETIME, '' + master.sys.fn_varbintohexstr (CONVERT(BINARY(4), ' + QUOTENAME(@column_name) + ')) + '')'''
   END
   ELSE IF (@data_type = 'text')
   BEGIN
      SET @sql = @sql + ''''''''' + REPLACE(CONVERT(VARCHAR(MAX), ' + QUOTENAME(@column_name) + '), '''''''', '''''''''''') + '''''''''
   END
   ELSE IF (@data_type IN ('ntext', 'xml'))
   BEGIN
      SET @sql = @sql + ''''''''' + REPLACE(CONVERT(NVARCHAR(MAX), ' + QUOTENAME(@column_name) + '), '''''''', '''''''''''') + '''''''''
   END
   ELSE IF (@data_type IN ('binary', 'varbinary'))
   BEGIN
      -- Use udf_varbintohexstr_big if available to avoid cutted binary data
      IF (@handle_big_binary = 1)
         SET @sql = @sql + ' dbo.udf_varbintohexstr_big (' + QUOTENAME(@column_name) + ')'
      ELSE
         SET @sql = @sql + ' master.sys.fn_varbintohexstr (' + QUOTENAME(@column_name) + ')'
   END
   ELSE IF (@data_type = 'timestamp')
   BEGIN
      SET @sql = @sql + '''CONVERT(TIMESTAMP, '' + master.sys.fn_varbintohexstr (CONVERT(BINARY(8), ' + QUOTENAME(@column_name) + ')) + '')'''
   END
   ELSE IF (@data_type = 'uniqueidentifier')
   BEGIN
      SET @sql = @sql + '''CONVERT(UNIQUEIDENTIFIER, '' + master.sys.fn_varbintohexstr (CONVERT(BINARY(16), ' + QUOTENAME(@column_name) + ')) + '')'''
   END
   ELSE IF (@data_type = 'image')
   BEGIN
      -- Use udf_varbintohexstr_big if available to avoid cutted binary data
      IF (@handle_big_binary = 1)
         SET @sql = @sql + ' dbo.udf_varbintohexstr_big (CONVERT(VARBINARY(MAX), ' + QUOTENAME(@column_name) + '))'
      ELSE
         SET @sql = @sql + ' master.sys.fn_varbintohexstr (CONVERT(VARBINARY(MAX), ' + QUOTENAME(@column_name) + '))'
   END
   ELSE
   BEGIN
      PRINT 'ERROR: Not supported data type: ' + @data_type
      RETURN
   END

   SET @sql = @sql + ' END'

   -- Script line end for finish or next column
   IF EXISTS (SELECT TOP 1 * FROM @columns WHERE ordinal_position > @pos)
      SET @sql = @sql + ' + '', '' +'
   ELSE
      SET @sql = @sql + ' + '

   -- Remember the data script
   IF (@insert IS NULL)
      SET @insert = @sql
   ELSE
      SET @insert = @insert + @crlf + @sql

   SET @pos = @pos + 1
END

-- Close the column names select
SET @select = @select + ''' +'

-- Print the INSERT INTO part
select @sqlstr = 'SELECT ''INSERT INTO ' + @table_name_to + ''' + '+CHAR(10) 

-- Print the column names if configured
IF (@column_names = 1)
BEGIN
 select @sqlstr =  @sqlstr+' ''('' + '
 select @sqlstr =  @sqlstr+@select+CHAR(10)
 select @sqlstr =  @sqlstr+' '')'' + '+CHAR(10)
END

select @sqlstr =  @sqlstr+' '' VALUES ('' +'+CHAR(10)

-- Print the data scripting
select @sqlstr =  @sqlstr+@insert+CHAR(10)

-- Script the end of the statement
select @sqlstr =  @sqlstr+' '');'''+CHAR(10)
select @sqlstr =  @sqlstr+' FROM ' + @table_name

print @sqlstr

exec(@sqlstr)
