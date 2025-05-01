SELECT  DISTINCT top 7 s.COBDate, fa.Jurisdiction, 
gr.Comments
into #t
FROM srf_main.EODTradestage s (NOLOCK) 
INNER JOIN srf_main.EODTradeJurisdiction fa (NOLOCK) 
ON s.Id = fa.EODTradeStageId 
		AND cobdate in ('2014-05-13') -- Pls Adjust Date 
AND fa.IsReportable = 'Y' 
and fa.State in ('REJ','WARN') 
inner join srf_main.GTRResponseStage gr on gr.EODTradeStageID = s.Id 
and fa.Jurisdiction = gr.Jurisdiction

--parse ; separated string
select #t.COBDate, #t.Jurisdiction, comment.Item
from #t
cross apply srf_main.fn_GetItemsFromList(Comments,';') as comment

--parse ; separated string and extract parts from parsed 
select #t.COBDate, #t.Jurisdiction,
substring(comment.item, 1, charindex('-',comment.item)-1) as ReasonCode,
substring(comment.item, charindex('-',comment.item)+1, len(comment.item)) as ReasonofRejection
from #t
cross apply srf_main.fn_GetItemsFromList(Comments,';') as comment