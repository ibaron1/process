
-- Only cataloged sql dependency
  

;WITH DEP_CTE AS 
(select d.id, d.depid
from sysdepends d 
join
(select name from sysobjects where type not in ('S','U')) obj
on object_name(d.id) = obj.name
where (select type from sysobjects where id = d.depid) not in ('S','U')
	union all
select d.id, d.depid
from sysdepends d 
join DEP_CTE as dep
on d.id = dep.depid
where not (d.id = dep.id and d.depid = dep.depid)
and (select type from sysobjects where id = d.depid) not in ('S','U'))
select distinct object_name(id) as Object, 
(select type from sysobjects where id = DEP_CTE.id) as ObjectType, 
'---->' as ' ',
object_name(depid) as DepedentObject,
(select type from sysobjects where id = DEP_CTE.depid) as DepedentObjectType
from DEP_CTE 
order by 1
OPTION (MAXRECURSION 0)


-- All objects dependency

;WITH DEP_CTE AS 
(select d.id, d.depid
from sysdepends d 
join
sys.objects obj
on object_name(d.id) = obj.name
	union all
select d.id, d.depid
from sysdepends d 
join DEP_CTE as dep
on d.id = dep.depid
join sysobjects o1 on o1.id = d.depid
where not (d.id = dep.id and d.depid = dep.depid)
)
select distinct object_name(id) as Object, 
(select type from sysobjects where id = DEP_CTE.id) as ObjectType, 
'---->' as ' ',
object_name(depid) as DepedentObject,
(select type from sysobjects where id = DEP_CTE.depid) as DepedentObjectType
from DEP_CTE 
order by 1
OPTION (MAXRECURSION 0)

-- Dependency for just several cataloged sql objects

declare @objname table(objname varchar(400))

insert @objname
values('srf_main.GetCollateral'),
('srf_main.EODValuationProcessingRewrite')

;WITH DEP_CTE AS 
(select d.id, d.depid
from sysdepends d 
join
sys.objects obj
on object_name(d.id) = obj.name
join @objname
on d.id  = object_id(objname)
	union all
select d.id, d.depid
from sysdepends d 
join DEP_CTE as dep
on d.id = dep.depid
join sysobjects o1 on o1.id = d.depid
where not (d.id = dep.id and d.depid = dep.depid)
)
select distinct object_name(id) as Object, 
(select type from sysobjects where id = DEP_CTE.id) as ObjectType, 
'---->' as ' ',
object_name(depid) as DepedentObject,
(select type from sysobjects where id = DEP_CTE.depid) as DepedentObjectType
from DEP_CTE 
order by 1
OPTION (MAXRECURSION 0)


