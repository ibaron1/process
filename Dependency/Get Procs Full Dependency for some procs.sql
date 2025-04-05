set nocount on

/***********************************************************

Comment out and not exists if nested level depth exceeds 4

***********************************************************/ 
declare @procs table(name varchar(200))

insert @procs
values 
('EnrichmentWrapper'),
('GetDatamaskingDecision'),
('GetEOD_ReportingParty'),
('GetEodDataFormatType'),
('GetEodFileHeaderRecords'),
('GetEodFileTrailerRecords'),
('GetNdmFlag'),
('GetPartyNotExists'),
('GetReportingParty_CD'),
('GetReportingParty_IR'),
('GetReportingPartyDetails'),
('Insert_EODTradeTable'),
('UpdateAllCompletedCheck'),
('UpdateEOD_Datamasking')
 

select object_name(d.id) as Calling, object_name(d.depid) as Called1
into #t1
from sysdepends d 
join
(select name from @procs) obj
on object_name(d.id) = obj.name
join sysobjects o
on d.depid = o.id and o.type in ('P', 'V','TR','IF', 'FN')
order by Calling
select Calling as Calling1, Called1 as Called2
into #t2 from #t1

select Calling, Called1, Called2
into #t3
from #t1 join #t2
on #t1.Called1 = #t2.Calling1
and Called2 <> Called1
order by 1,2,3

select #t3.Calling, #t3.Called1, #t3.Called2, #t1.Called1 as Called3
into #t4
from #t3 join #t1
on #t3.Called2 = #t1.Calling
/*
and not exists 
(select 1 from #t1 where Calling = #t3.Calling and (Called1=#t3.Called1 or Called1=#t3.Called2))
*/
order by 1,2,3,4



select #t4.Calling, #t4.Called1, #t4.Called2, #t4.Called3, #t2.Called2 as Called4
into #t5
from #t4 join #t2
on #t4.Called3 = #t2.Calling1
/*
and not exists 
(select 1 from #t2 where Calling = #t4.Calling and 
 (Called1=#t4.Called1 or Called2=#t4.Called2 or Called3=#t4.Called3))
 */
order by 1,2,3,4,5

select Calling, Called1, #t5.Called2, #t5.Called3, #t5.Called4, #t2.Called2 as Called5
into #t6
from #t5 join #t2
on #t5.Called2 = #t2.Calling1
and not exists 
(select 1 from #t4 where Calling = #t5.Calling and 
 (Called1=#t5.Called1 or Called2=#t5.Called2 or Called3=#t5.Called3 or Called4=#t5.Called4))
order by 1,2,3,4,5,6

select Calling, Called1, #t6.Called2, #t6.Called3, #t6.Called4, #t6.Called5, #t2.Called2 as Called6
into #t7
from #t6 join #t2
on #t6.Called2 = #t2.Calling1
and not exists 
(select 1 from #t5 where Calling = #t6.Calling and 
 (Called1=#t6.Called1 or Called2=#t6.Called2 or Called3=#t6.Called3 or Called4=#t6.Called4 or Called5=#t6.Called5))
order by 1,2,3,4,5,6,7

select Calling,Called1,#t7.Called2,#t7.Called3,#t7.Called4,#t7.Called5,#t7.Called6,#t2.Called2 as Called7
into #t8
from #t7 join #t2
on #t7.Called2 = #t2.Calling1
and not exists 
(select 1 from #t6 where Calling = #t7.Calling and 
 (Called1=#t7.Called1 or Called2=#t7.Called2 or Called3=#t7.Called3 or Called4=#t7.Called4 
  or Called5=#t7.Called5 or Called6=#t7.Called6))
order by 1,2,3,4,5,6,7,8

select Calling+' ->'+Called1+' ->'+Called2+' ->'+Called3+' ->'+Called4+' ->'+Called5+' ->'+Called6+' ->'+Called7
from #t8
union all
select Calling+' ->'+Called1+' ->'+Called2+' ->'+Called3+' ->'+Called4+' ->'+Called5+' ->'+Called6
from #t7 where not exists 
(select 1 from #t8 where Calling = #t8.Calling and Called1=#t8.Called1 and Called2=#t8.Called2 
 and Called3=#t8.Called3 and Called4=#t8.Called4 and Called5=#t8.Called5 and Called6=#t8.Called6)
union all
select Calling+' ->'+Called1+' ->'+Called2+' ->'+Called3+' ->'+Called4+' ->'+Called5
from #t6 where not exists 
(select 1 from #t7 where Calling = #t6.Calling and Called1=#t6.Called1 and Called2=#t6.Called2 
 and Called3=#t6.Called3 and Called4=#t6.Called4 and Called5=#t6.Called5)
union all
select Calling+' ->'+Called1+' ->'+Called2+' ->'+Called3+' ->'+Called4
from #t5 where not exists 
(select 1 from #t6 where Calling = #t5.Calling and Called1=#t5.Called1 and Called2=#t5.Called2 
 and Called3=#t5.Called3 and Called4=#t5.Called4)
union all
select Calling+' ->'+Called1+' ->'+Called2+' ->'+Called3
from #t4 where not exists 
(select 1 from #t5 where Calling = #t4.Calling and Called1=#t4.Called1 and Called2=#t4.Called2 and Called3=#t4.Called3)
union all
select Calling+' ->'+Called1+' ->'+Called2
from #t3 where not exists 
(select 1 from #t4 where Calling = #t3.Calling and Called1=#t3.Called1 and Called2=#t3.Called2)
union all
select Calling+' ->'+Called1
from #t1 where not exists 
(select 1 from #t3 where Calling = #t1.Calling and Called1=#t1.Called1)
order by 1

drop table #t1,#t2,#t3,#t4,#t5, #t6, #t7, #t8

go