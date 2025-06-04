declare @update_dt datetime = getdate()

update top (1) [iborop].[FactAdditionalInternationalProductDescription]
set update_dt = @update_dt

update top (1) a
set update_dt = @update_dt
from dbo.[FactAdditionalInternationalProductDescription] a
join [iborop].[FactAdditionalInternationalProductDescription] b
on a.ProductKey = b.ProductKey
and a.CultureName = b.CultureName


select top 1 update_dt from [iborop].[FactAdditionalInternationalProductDescription]