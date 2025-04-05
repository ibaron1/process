declare @depends table
(name sysname,
type sysname,
updated sysname,
selected sysname,
[column] sysname null)

insert @depends
exec sp_depends N'srf_main.sfreport'

select distinct name as tbl from @depends

-- for proc, trg, view, func

declare @ObjName varchar(30)= 'srf_main.sfreport'
select distinct 
OBJECT_SCHEMA_NAME(d.id)+'.'+ 
cast(object_name(depid) as varchar(40)) as tbl
from sysdepends d, sys.objects o
where d.id = o.object_id
and  o.object_id = object_id(@objname)
and exists
(select '1' from sys.objects
 where object_id = d.depid and type='U')