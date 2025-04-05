set nocount on

declare @tbl varchar(30)

select @tbl = 'pt_trmast'

select name into #tbl from sysobjects
where type='U'

select object_name(d.id) ProcDepOnTbl
into #ProcsDepOnTbl
from sysdepends d
where object_name(depid) in (select name from #tbl)
and exists
(select '1' from sysobjects where id = d.id and type='P')

select object_name(id) CallingProc, 
    object_name(depid) CalledProc
into #allProcsDepend
from sysdepends d
where exists
(select '1' from sysobjects where id = d.id and type='P')
and exists
(select '1' from sysobjects where id = d.depid and type='P')

create index i on #allProcsDepend(CallingProc)

create table #depProcs
(CallingProc varchar(30), CalledProc varchar(30))

insert #depProcs
select distinct a.CallingProc, a.CalledProc
from #allProcsDepend a, sysobjects o
where a.CallingProc = o.name
and o.type='P'

while exists (select '1' from #allProcsDepend a, #depProcs t 
              where a.CallingProc = t.CalledProc)
begin
    insert #depProcs
    select distinct a.CallingProc, a.CalledProc
    from #allProcsDepend a, #depProcs t
    where a.CallingProc = t.CalledProc

  delete #allProcsDepend
  from #allProcsDepend a, #depProcs t 
  where a.CallingProc = t.CallingProc and a.CalledProc = t.CalledProc
end

select distinct CallingProc procname
into #tmp
from #depProcs
union
select distinct CalledProc
from #depProcs

select * from #tmp

select * from #tmp
where exists 
(select '1' from #ProcsDepOnTbl
 where ProcDepOnTbl = #tmp.procname) 

drop table #ProcsDepOnTbl, #allProcsDepend, #depProcs, #tmp 
drop table #tbl


