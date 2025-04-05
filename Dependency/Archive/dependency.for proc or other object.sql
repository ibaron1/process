=================== tables ==============================
select distinct 
OBJECT_SCHEMA_NAME(d.id)+'.'+ 
cast(object_name(depid) as varchar(40)) as [Dependent object],
do.type as [Dependent object type]
from sysdepends d join sys.objects o
on d.id = OBJECT_ID('srf_main.GetORCDailyExtractArrivedDT_RT')
join sys.objects do
on d.depid = do.object_id
and do.type not in ('S','P')

======================== dependent compiled sql for the object =====================
set nocount on

declare @ObjName varchar(30)
select  @ObjName = 'imssp_holdings_measurisk'

select distinct object_name(d.id) 'Calling', object_name(d.depid) 'Called'
--into #dependObj
from sysdepends d, sysobjects o
where object_name(d.id) = @ObjName
and d.depid = o.id and o.type = 'P'

======================== All dependencies in a database =========================
set nocount on

select name as tbl 
into #tbls
from sysobjects
where type in ('U', 'V', 'FN', 'IF', 'TF')

select distinct cast(object_name(d.id) as varchar(40)) ObjName, 
case o.type when 'P' then 'Proc' when 'TR' then 'Trigger' when 'V' then 'View' 
			when 'V' then 'view'
			when 'FN' then 'SQL scalar function'
			when 'IF' then 'SQL inline table-valued function'
			when 'TF' then 'SQL table-valued-function' end as ObjType,
cast(object_name(depid) as varchar(40)) as DepObjName,
(select case type 
		when 'U' then 'table' 
		when 'V' then 'view' 
		when 'FN' then 'SQL scalar function'
		when 'IF' then 'SQL inline table-valued function'
		when 'TF' then 'SQL table-valued-function' end
 from sys.objects
 where object_id = d.depid) as DepObjType
from sysdepends d, sys.objects o, #tbls t 
where d.id = o.object_id
and object_name(depid) = t.tbl 
order by cast(object_name(depid) as varchar(40))
compute count(cast(object_name(depid) as varchar(40)))
by cast(object_name(depid) as varchar(40))

drop table #tbls

======================== All dependencies resolution in a database =========================
-- create table top(name varchar(30))
-- select * from  tempdb..top

set nocount on 

select name as tbl 
into #tbls
from sysobjects
where type='U'

select object_name(d.id) Obj, 
case o.type when 'P' then 'Proc' when 'TR' then 'Trigger' when 'V' then 'View' end as ObjType,
object_name(depid) DepObj,
case o.type when 'P' then 'Proc' when 'TR' then 'Trigger' when 'V' then 'View' end as DepObjType,
t.tbl as Ref_Tbl_ForObj 
into #AllRefs
from #tbls t, sysdepends d, sysobjects o, sysobjects o1 
where d.id = o.id
and object_name(d.depid) = t.tbl 
and d.depid = o1.id
order by Obj



-- select * from #AllRefs

drop table #tbls
--drop table #AllRefs 








