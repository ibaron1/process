set nocount on

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
from #allProcsDepend a, GPS..procs10 t
where a.CallingProc = t.procname

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

select * from #depProcs d
order by CallingProc