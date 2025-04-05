set nocount on

declare @searched_String varchar(400), @ExecutedProc varchar(30)

/**** stat-t 14 line 149 in proc GPS.imssub_hld_income on GLSR ****/

select 
@searched_String = 'FeedActivity%FeedIdType'
,@ExecutedProc = 'EODValuationProcessingRewrite'

create table #procs_called
(procname varchar(30), tbl varchar(7))

select distinct object_name(id) Searched_Obj
into #SearchedObj
from syscomments
where text like '%'+@searched_String+'%'

if exists (select '1' from #SearchedObj where Searched_Obj = @ExecutedProc)
begin
  select 'Proc containing text "'+@searched_String+'" - '+

name as tbl 
into #procs
from sysobjects
where type='P'

select object_name(d.id) Obj, 
case o.type when 'P' then 'Proc' when 'TR' then 'Trigger' end as ObjType,
object_name(depid) DepObj
,case o1.type when 'P' then 'Proc' when 'TR' then 'Trigger' end as DepObjType,
t.tbl as Ref_Tbl_ForObj 
into #AllRefs
from #procs t, sysdepends d, sysobjects o, sysobjects o1 
where object_name(d.depid) = t.tbl 
and d.id = o.id
and d.depid = o1.id
order by Obj

select a.Obj, a.ObjType, a.DepObj, a.DepObjType
into #OneUp
from #SearchedObj s, #AllRefs a
where s.Searched_Obj = a.DepObj 

end


-- select * from #AllRefs
-- select * from #bottom
-- select * from #SearchedObj
drop table #procs
/*
drop table #AllRefs
drop table #SearchedObj
drop table #OneUp
drop table #procs_called
*/

