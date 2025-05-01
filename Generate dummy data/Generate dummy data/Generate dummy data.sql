
declare @tbl varchar(200) = 'srf_main.SFreportEODdata_pending'
declare @NoOfRows int = 10

Declare @icount int
declare @qry varchar(max)
set @qry = ' '
set @icount = 0

while @icount < @NoOfRows
begin
    select @qry = @qry
    +
    case when c.column_id = 1 then
        'insert into ' + SCHEMA_NAME(t.schema_id) + '.[' + t.name + '] values('
    else
        ''
    end
    +
    -- incase the column is identity, i dont include it in the insert
    case when c.is_identity = 0 then
        case when ty.name in ('bit','bigint','int','smallint','tinyint','float','decimal','numeric','money','smallmoney','real') then
            substring(CAST(  round(RAND() * 1000,0) AS varchar),1,c.max_length)
        when ty.name in ('binary','varbinary') then
            substring('0x546869732069732044756D6D792044617461',1,c.max_length)
        when ty.name In ('varchar','char','text') then
            '''' + substring('Dummy This is Dummy Data',1,c.max_length)  + '''' 
        when ty.name In ('nchar','nvarchar','ntext') then
            '''' + substring('Dummy This is Dummy Data',1,c.max_length / 2)  + ''''             
        when ty.name in('date','time','datetime','datetime2','smalldatetime','datetimeoffset') then
            '''' + convert(varchar(50),dateadd(D,Round(RAND() * 1000,1),getdate()),121) + '''' 
        when ty.name in ('uniqueidentifier') then
            cast(NEWID() as varchar(33))
        else
            ''
        end
        + 
        case when c.column_id = (Select MAX(insc.column_id) from sys.columns insc where insc.OBJECT_ID = c.OBJECT_ID) then
            ');'
        else
            ','
        end
    else
        ''  
    end

    FROM sys.tables AS t
    INNER JOIN sys.columns c ON t.OBJECT_ID = c.OBJECT_ID
    INNER JOIN sys.types AS ty ON c.user_type_id=ty.user_type_id
    where t.OBJECT_ID = OBJECT_ID(@tbl)
    
    ORDER BY t.name,c.column_id; 
    set @icount = @icount + 1

    --execute the insert statments
    --Select (@qry)
    exec (@qry)
    --print @qry
    Set @qry = ' ' 
end


