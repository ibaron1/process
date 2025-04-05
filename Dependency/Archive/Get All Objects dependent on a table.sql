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
and depid = object_id('srf_main.TradeMessagePayload')

drop table #tbls