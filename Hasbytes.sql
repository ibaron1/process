drop table if exists #a
create table #a(a int null, b int null, c int null)
insert #a values
(1,2,3)
,(1,3,3)
,(1,null,3)

drop table if exists #b
create table #b(a int null, b int null, c int null)
insert #b values
(1,2,3)
,(1,4,3)
,(1,1,3)

select a,b,c from #a
except 
select a,b,c from #b

DECLARE @RowHash VARCHAR(MAX)
,@ColumnList_RowHash VARCHAR(MAX) = 'a,b,c';

select * FROM STRING_SPLIT(@ColumnList_RowHash,',')

select CONCAT((SELECT STRING_AGG(CAST(CONCAT('CAST(',value,' AS VARCHAR(100))+'' |''') AS VARCHAR(MAX)), '+') FROM STRING_SPLIT(@ColumnList_RowHash,',')),'))') 

select *,CONVERT(BIGINT, HASHBYTES('SHA2_256',CONCAT((SELECT STRING_AGG(CAST(CONCAT('CAST(',value,' AS VARCHAR(100))+'' |''') AS VARCHAR(MAX)), '+') FROM STRING_SPLIT(@ColumnList_RowHash,',')),'))'))) as RowHash
from #a
go

select a, b, c
,CONCAT((SELECT STRING_AGG(CAST(CONCAT('CAST(',value,' AS VARCHAR(100))+'' |''') AS VARCHAR(MAX)), '+') FROM STRING_SPLIT(@ColumnList_RowHash,',')),'))') 
 ,CONVERT(BIGINT, HASHBYTES('SHA2_256',CONCAT((SELECT STRING_AGG(CAST(CONCAT('CAST(',value,' AS VARCHAR(100))+'' |''') AS VARCHAR(MAX)), '+') FROM STRING_SPLIT(@ColumnList_RowHash,',')),'))'))) as RowHash
 from #a

 select a, b, c
 ,CONCAT((SELECT STRING_AGG(CAST(CONCAT('CAST(',value,' AS VARCHAR(100))+'' |''') AS VARCHAR(MAX)), '+') FROM STRING_SPLIT(@ColumnList_RowHash,',')),'))') 
 ,CONVERT(BIGINT, HASHBYTES('SHA2_256',CONCAT((SELECT STRING_AGG(CAST(CONCAT('CAST(',value,' AS VARCHAR(100))+'' |''') AS VARCHAR(MAX)), '+') FROM STRING_SPLIT(@ColumnList_RowHash,',')),'))'))) as RowHash
 from #b

-------------------------------------- MAIN ------------------------------
SET CONCAT_NULL_YIELDS_NULL OFF;

DECLARE @RowHash VARCHAR(MAX)
,@ColumnList_RowHash VARCHAR(MAX) = 'a,b,c';


select c.name as clmn from tempdb..sysobjects o 
join tempdb..syscolumns c
on o.id = c.id
where o.name like '#a[^a-Z][^0-9]%'

;with GetClmns
as
(select c.name as clmn from tempdb..sysobjects o 
join tempdb..syscolumns c
on o.id = c.id
where o.name like '#a[^a-Z][^0-9]%')
select a, b, c
	,CONVERT(BIGINT, HASHBYTES('SHA2_256', (SELECT STRING_AGG(CAST(clmn AS VARCHAR(100)),'|') FROM GetClmns))) AS RowHash
	--, CONVERT(BIGINT, HASHBYTES('SHA2_256',concat(cast(a as varchar(100)),'|', cast(b as varchar(100)),'|', cast(c as varchar(100)),'|'))) as RowHash1
from #a

;with cte_a
as
(select a, b, c
	, CONVERT(BIGINT, HASHBYTES('SHA2_256',concat(cast(a as varchar(100)),'|', cast(b as varchar(100)),'|', cast(c as varchar(100)),'|'))) as RowHash
 from #a)
 ,cte_b
 as
 (select a, b, c
 	, CONVERT(BIGINT, HASHBYTES('SHA2_256',concat(cast(a as varchar(100)),'|', cast(b as varchar(100)),'|', cast(c as varchar(100)),'|'))) as RowHash
 from #b)
select cte_a.a, cte_a.b, cte_a.c,cte_a.RowHash [cte_a.RowHash]
from cte_a
where not exists 
(select 1 from cte_b
 where cte_a.RowHash = cte_b.RowHash)


