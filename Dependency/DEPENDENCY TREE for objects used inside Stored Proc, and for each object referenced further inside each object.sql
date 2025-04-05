if object_id('tempdb..#base_objects') is not null
  drop table #base_objects
create table #base_objects
(schemaname varchar(128)
,objectname varchar(128)
)

insert into #base_objects
values ('DataExport_Dev', 'Populate_AllDataMartTables')
--,('schema', 'object of any type') --must be in the same database

;with DepTree
  (top_level_name, referenced_id, referenced_schema, referenced_name, referencing_id, referencing_schema, referencing_name, NestLevel, callstack, typedesc
  )
as
(select schema_name(o.schema_id) + '.' + o.name as top_level_name
  , o.object_id as referenced_id
  , schema_name(o.schema_id) as referenced_schema
  , o.name as referenced_name
  , o.object_id as referencing_id
  , schema_name(o.schema_id) as referencing_schema
  , o.name as referencing_name
  , 0 as NestLevel
     , cast ('|' + schema_name(o.schema_id) + '.' + o.name + '|' as nvarchar(max)) as callstack
  , o.type_desc as typedesc
  from sys.objects o
  inner join #base_objects ro
   on ro.schemaname = schema_name(o.schema_id)
   and ro.objectname = o.name

union all

  SELECT r.top_level_name
   , ref.referenced_id
   , ref.referenced_schema
   , ref.referenced_name
   , ref.referencing_id
   , ref.referencing_schema
   , ref.referencing_name
   , ref.NestLevel
   , callstack + ref.objectname + '|' as callstack
   , cast(ref.typedesc as nvarchar(60)) as typedesc
  FROM sys.sql_expression_dependencies d1 
  JOIN DepTree r 
  ON d1.referencing_id = r.referenced_id
  outer apply (select ob2.object_id as referenced_id
        , schema_name(ob2.schema_id) as referenced_schema
        , ob1.name as referenced_name
        , schema_name(ob2.schema_id) + '.' + ob2.name as objectname
        , ob1.object_id as referencing_id
        , schema_name(ob1.schema_id) as referencing_schema
        , ob1.name as referencing_name
        , NestLevel + 2 as NestLevel
        , cast(ob2.type_desc as nvarchar(60)) as typedesc
      from sys.synonyms sy1
      inner join sys.objects ob1
       on ob1.object_id = sy1.object_id
      inner join sys.objects ob2
      on '[' + schema_name(ob2.schema_id) + '].[' + ob2.name + ']' = sy1.base_object_name
      where sy1.object_id = d1.referenced_id
      union all
      select d1.referenced_id
        , schema_name(ob1.schema_id) as referenced_schema
        , ob1.name as referenced_name
        , schema_name(ob1.schema_id) + '.' + ob1.name as objectname
        , r.referencing_id
        , r.referencing_schema
        , r.referencing_name
        , NestLevel + 1 as NestLevel
        , cast(ob1.type_desc as nvarchar(60)) as typedesc
      from sys.objects ob1
      where ob1.object_id = d1.referenced_id
      union all
      select d1.referenced_id
        , schema_name(ty1.schema_id) as referenced_schema
        , ty1.name as referenced_name
        , schema_name(ty1.schema_id) + '.' + ty1.name as objectname
        , r.referencing_id
        , r.referencing_schema
        , r.referencing_name
        , NestLevel + 1 as NestLevel
        , cast(d1.referenced_class_desc as nvarchar(60)) as typedesc
      from sys.table_types ty1
      where ty1.user_type_id = d1.referenced_id
      ) ref
 where callstack not like '%|' + ref.objectname + '|%'
)
select *
from DepTree dt

where NestLevel > 0
option (maxrecursion 5000);