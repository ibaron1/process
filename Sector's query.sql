-- Sector Risk Pull
-- Build Helper Table
SET NOCOUNT ON;
SET IMPLICIT_TRANSACTIONS OFF;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DROP TABLE IF EXISTS #temp_breakout_define
DROP TABLE IF EXISTS #temp_mpc1_limit
DROP TABLE IF EXISTS #temp
SELECT MAX(asof_dt) as max_asof_dt into #temp FROM dn_load_status WITH (NOLOCK) WHERE end_time IS NOT NULL

select distinct
pgim_sector,
CASE pgim_sector
WHEN 'Asset Backed Securities' THEN 0
WHEN 'Other' THEN 0
WHEN 'High Yield' THEN 1
WHEN 'RMBS Credit' THEN 0
WHEN 'Municipal' THEN 0
WHEN 'Agency, SBA, and FHA' THEN 0
WHEN 'Non-US Govt Related' THEN 0
WHEN 'Total Cash' THEN 0
WHEN 'Swap' THEN 0
WHEN 'Investment Grade Corp' THEN 1
WHEN 'NULL' THEN 0
WHEN 'Government' THEN 0
WHEN 'Mortgages & CMO' THEN 0
WHEN 'CMBS' THEN 0
WHEN 'Emerging Markets' THEN 1
WHEN 'OTC Clearing Balances' THEN 0
WHEN 'Bank Loans' THEN 1
WHEN 'CLO' THEN O
WHEN 'FX' THEN 0
ELSE 0
END as full_rating_breakout,
CASE pgim_sector
WHEN 'Asset Backed Securities' THEN 1
WHEN 'Other' THEN 0
WHEN 'High Yield' THEN 0
WHEN 'RMBS Credit' THEN 1
WHEN 'Municipal' THEN 0
WHEN 'Agency, SBA, and FHA' THEN 0
WHEN 'Non-US Govt Related' THEN O
WHEN 'Total Cash' THEN O
WHEN 'Swap' THEN 0
WHEN 'Investment Grade Corp' THEN 0
WHEN 'NULL' THEN O
WHEN 'Government' THEN O
WHEN 'Mortgages & CMO' THEN 0
WHEN 'CMBS' THEN 1
WHEN 'Emerging Markets' THEN 0
WHEN 'OTC Clearing Balances' THEN 0
WHEN 'Bank Loans' THEN 0
WHEN 'CLO' THEN 1
WHEN 'FX' THEN O
ELSE 0
END AS aaa_aa_breakout
INTO #temp_breakout_define
from dn_security_ts
WHERE asof_dt =(select max_asof_dt from #temp)

select
CAST (memb_code as varchar(50)) as portfolio_name,
sum(case when portfolio_limit_name = 'SpreadPC1' then portfolio_limit.value else 0 end) as mpc1_limit,
sum(case when portfolio_limit_name = 'TotalTE' then portfolio_limit.value else 0 end) as te_limit
into #temp_mpc1_limit
from portfolio_limit
where
portfolio_limit.p_end_dt = '12/31/9999' and
portfolio_limit.portfolio_limit_name in ('SpreadPC1', 'TotalTE' )
group by
memb_code;

--Pull Sector Holdings
select
dn_security_ts.pgim_sector,
dn_portfolio_group_mandate.portfolio_name,
dn_portfolio_group_mandate.pag_mandate,
dn_port_bmrk_position.synthetic_look_through,
CASE WHEN dn_security.currency IN ('USD', 'GBP' , 'EUR' ) THEN dn_security.currency ELSE 'Other' END as currency_group,
dn_security.currency,
CASE WHEN #temp_breakout_define.aaa_aa_breakout = 1 then
case when mid_value >= 29 THEN 'AAA' WHEN mid_value >= 26 THEN 'AA' ELSE 'Below AA' END
WHEN #temp_breakout_define.full_rating_breakout = 1 THEN
case when sec_type = 'SWAP_CDSWAP' THEN 'CDX/CDS' WHEN sec_type = 'SYNTH_SWAPTION' THEN 'CDX/CDS Options' when mid_value >= 26 THEN ' AAA.AA' WHEN mid_value >= 23 THEN 'A' WHEN mid_value >= 20 THEN 'BBB' WHEN mid_value >= 17 THEN 'BB' WHEN mid_value >= 14 THEN 'B' ELSE 'Below B' END
ELSE 'NA' END AS rating,
case
when coalesce(underlying_analytic.pru_wal, dn_analytic.pru_wal) < 3 then '01-03'
when coalesce(underlying_analytic.pru_wal, dn_analytic.pru_wal) < 5 then '03-05'
when coalesce(underlying_analytic.pru_wal, dn_analytic.pru_wal) < 10 then '05-10'
ELSE '10+'
END AS wal_bucket,
#temp_mpc1_limit.mpc1_limit,
#temp_mpc1_limit.te_limit,
sum(dn_port_bmrk_position.port_pct_mv) as port_mv,
sum(dn_port_bmrk_position.bmrk_pct_mv) as bmrk_mv,
sum(dn_port_bmrk_position.port_pct_adj_nmv_mv) as port_nmv,
sum(dn_port_bmrk_position.bmrk_pct_adj_nmv_mv) as bmrk_nmv,
sum(dn_port_bmrk_position.port_unified_mpc1_sprd_contrib) as port_mpc1,
sum(dn_port_bmrk_position.bmrk_unified_mpc1_sprd_contrib) as bmrk_mpc1,
sum(dn_port_bmrk_position.port_unified_rec_sprd_contrib) as port_rec,
sum(dn_port_bmrk_position.bmrk_unified_rec_sprd_contrib) as bmrk_rec,
sum(dn_port_bmrk_position.port_spread_dur_contrib) as port_spread_dur,
sum(dn_port_bmrk_position.bmrk_spread_dur_contrib) as bmrk_spread_dur,
case when sum(dn_port_bmrk_position.port_pct_adj_nmv_mv) = 0 THEN 0 ELSE sum(dn_port_bmrk_position.port_pct_adj_nmv_mv * dn_analytic.oas) / (sum(dn_port_bmrk_position.port_pct_mv) + 0.0000001) END AS port_oas,
case when sum(dn_port_bmrk_position.bmrk_pct_adj_nmv_mv) = 0 THEN 0 ELSE sum(dn_port_bmrk_position.bmrk_pct_adj_nmv_mv * dn_analytic.oas) / (sum(dn_port_bmrk_position.bmrk_pct_mv) + 0.0000001) END AS bmrk_oas
from dn_security_ts
JOIN dn_security ON dn_security.asset_id = dn_security_ts.asset_id AND dn_security_ts.asof_dt = (select max_asof_dt from #temp)
JOIN #temp_breakout_define ON #temp_breakout_define.pgim_sector = dn_security_ts.pgim_sector
JOIN dn_port_bmrk_position on dn_port_bmrk_position.asset_id = dn_security_ts.asset_id and dn_port_bmrk_position.asof_dt = dn_security_ts.asof_dt
JOIN dn_analytic ON dn_analytic.asset_id = dn_security_ts.asset_id and dn_analytic.asof_dt = dn_security_ts.asof_dt and dn_analytic.pricing_source = coalesce(dn_port_bmrk_position.port_pricing_source, dn_port_bmrk_position.bmrk_pricing_source)
LEFT JOIN dn_analytic as underlying_analytic ON underlying_analytic.asset_id = dn_security.underlying_asset_id and underlying_analytic.asof_dt = dn_security_ts.asof_dt and underlying_analytic.pricing_source = coalesce(dn_port_bmrk_position.port_pricing_source, dn_port_bmrk_position.bmrk_pricing_source)
JOIN dn_portfolio_group_mandate on dn_portfolio_group_mandate.portfolio_id = dn_port_bmrk_position.portfolio_id join #temp_mpc1_limit ON #temp_mpc1_limit.portfolio_name = dn_portfolio_group_mandate.portfolio_name
group by
dn_security_ts.pgim_sector,
dn_portfolio_group_mandate.portfolio_name,
dn_portfolio_group_mandate.pag_mandate,
dn_port_bmrk_position.synthetic_look_through,
CASE WHEN dn_security.currency IN ('USD' , 'GBP' , 'EUR' ) THEN dn_security.currency ELSE 'Other' END,
dn_security.currency,
CASE WHEN #temp_breakout_define.aaa_aa_breakout = 1 then
case when mid_value >= 29 THEN 'AAA' WHEN mid_value >= 26 THEN 'AA' ELSE 'Below AA' END
WHEN #temp_breakout_define.full_rating_breakout = 1 THEN
case when sec_type = 'SWAP_CDSWAP' THEN 'CDX/CDS' WHEN sec_type = 'SYNTH_SWAPTION' THEN 'CDX/CDS Options' when mid_value >= 26 THEN 'AAA.AA' WHEN mid_value >= 23 THEN 'A' WHEN mid_value >= 20 THEN 'BBB' WHEN mid_value >= 17 THEN 'BB' WHEN mid_value >= 14 THEN 'B' ELSE 'Below B' END
ELSE 'NA' END,
case
when coalesce(underlying_analytic.pru_wal, dn_analytic.pru_wal) < 3 then '01-03'
when coalesce(underlying_analytic.pru_wal, dn_analytic.pru_wal) < 5 then '03-05'
when coalesce(underlying_analytic.pru_wal, dn_analytic.pru_wal) < 10 then '05-10'
ELSE '10+'
END,
#temp_mpc1_limit.mpc1_limit,
#temp_mpc1_limit.te_limit


