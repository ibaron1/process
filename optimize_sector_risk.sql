-- Optimized Sector Risk Query
SET NOCOUNT ON;
SET IMPLICIT_TRANSACTIONS OFF;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @asof_dt DATE;
SELECT @asof_dt = MAX(asof_dt) FROM dn_load_status WITH (NOLOCK) WHERE end_time IS NOT NULL;

-- Pre-filter large tables
SELECT asset_id, pgim_sector, mid_value, sec_type
INTO #dn_security_ts_filtered
FROM dn_security_ts WITH (NOLOCK)
WHERE asof_dt = @asof_dt;

SELECT asset_id, portfolio_id, synthetic_look_through,
       port_pct_mv, bmrk_pct_mv, port_pct_adj_nmv_mv, bmrk_pct_adj_nmv_mv,
       port_unified_mpc1_sprd_contrib, bmrk_unified_mpc1_sprd_contrib,
       port_unified_rec_sprd_contrib, bmrk_unified_rec_sprd_contrib,
       port_spread_dur_contrib, bmrk_spread_dur_contrib,
       port_pricing_source, bmrk_pricing_source
INTO #dn_port_bmrk_position_filtered
FROM dn_port_bmrk_position WITH (NOLOCK)
WHERE asof_dt = @asof_dt;

-- Breakout definition
SELECT DISTINCT pgim_sector,
       CASE pgim_sector
            WHEN 'High Yield' THEN 1
            WHEN 'Investment Grade Corp' THEN 1
            WHEN 'Emerging Markets' THEN 1
            WHEN 'Bank Loans' THEN 1
            WHEN 'CLO' THEN 0
            ELSE 0 END AS full_rating_breakout,
       CASE pgim_sector
            WHEN 'Asset Backed Securities' THEN 1
            WHEN 'RMBS Credit' THEN 1
            WHEN 'CMBS' THEN 1
            WHEN 'CLO' THEN 1
            ELSE 0 END AS aaa_aa_breakout
INTO #temp_breakout_define
FROM #dn_security_ts_filtered;

-- Portfolio Limits
SELECT CAST(memb_code AS varchar(50)) AS portfolio_name,
       SUM(CASE WHEN portfolio_limit_name = 'SpreadPC1' THEN value ELSE 0 END) AS mpc1_limit,
       SUM(CASE WHEN portfolio_limit_name = 'TotalTE' THEN value ELSE 0 END) AS te_limit
INTO #temp_mpc1_limit
FROM portfolio_limit
WHERE p_end_dt = '99991231' -- avoid date conversion
  AND portfolio_limit_name IN ('SpreadPC1', 'TotalTE')
GROUP BY memb_code;

-- Main aggregation
SELECT ts.pgim_sector,
       pgm.portfolio_name,
       pgm.pag_mandate,
       bmrk.synthetic_look_through,
       CASE WHEN s.currency IN ('USD', 'GBP', 'EUR') THEN s.currency ELSE 'Other' END AS currency_group,
       s.currency,
       CASE
           WHEN d.aaa_aa_breakout = 1 THEN CASE WHEN ts.mid_value >= 29 THEN 'AAA' WHEN ts.mid_value >= 26 THEN 'AA' ELSE 'Below AA' END
           WHEN d.full_rating_breakout = 1 THEN CASE
                WHEN ts.sec_type = 'SWAP_CDSWAP' THEN 'CDX/CDS'
                WHEN ts.sec_type = 'SYNTH_SWAPTION' THEN 'CDX/CDS Options'
                WHEN ts.mid_value >= 26 THEN 'AAA.AA'
                WHEN ts.mid_value >= 23 THEN 'A'
                WHEN ts.mid_value >= 20 THEN 'BBB'
                WHEN ts.mid_value >= 17 THEN 'BB'
                WHEN ts.mid_value >= 14 THEN 'B'
                ELSE 'Below B' END
           ELSE 'NA' END AS rating,
       CASE
           WHEN COALESCE(ua.pru_wal, a.pru_wal) < 3 THEN '01-03'
           WHEN COALESCE(ua.pru_wal, a.pru_wal) < 5 THEN '03-05'
           WHEN COALESCE(ua.pru_wal, a.pru_wal) < 10 THEN '05-10'
           ELSE '10+' END AS wal_bucket,
       lim.mpc1_limit,
       lim.te_limit,
       SUM(bmrk.port_pct_mv) AS port_mv,
       SUM(bmrk.bmrk_pct_mv) AS bmrk_mv,
       SUM(bmrk.port_pct_adj_nmv_mv) AS port_nmv,
       SUM(bmrk.bmrk_pct_adj_nmv_mv) AS bmrk_nmv,
       SUM(bmrk.port_unified_mpc1_sprd_contrib) AS port_mpc1,
       SUM(bmrk.bmrk_unified_mpc1_sprd_contrib) AS bmrk_mpc1,
       SUM(bmrk.port_unified_rec_sprd_contrib) AS port_rec,
       SUM(bmrk.bmrk_unified_rec_sprd_contrib) AS bmrk_rec,
       SUM(bmrk.port_spread_dur_contrib) AS port_spread_dur,
       SUM(bmrk.bmrk_spread_dur_contrib) AS bmrk_spread_dur,
       CASE WHEN SUM(bmrk.port_pct_adj_nmv_mv) = 0 THEN 0 ELSE SUM(bmrk.port_pct_adj_nmv_mv * a.oas) / (SUM(bmrk.port_pct_mv) + 0.0000001) END AS port_oas,
       CASE WHEN SUM(bmrk.bmrk_pct_adj_nmv_mv) = 0 THEN 0 ELSE SUM(bmrk.bmrk_pct_adj_nmv_mv * a.oas) / (SUM(bmrk.bmrk_pct_mv) + 0.0000001) END AS bmrk_oas
FROM #dn_security_ts_filtered ts
JOIN dn_security s ON s.asset_id = ts.asset_id
JOIN #temp_breakout_define d ON d.pgim_sector = ts.pgim_sector
JOIN #dn_port_bmrk_position_filtered bmrk ON bmrk.asset_id = ts.asset_id
JOIN dn_analytic a ON a.asset_id = ts.asset_id AND a.asof_dt = @asof_dt AND a.pricing_source = COALESCE(bmrk.port_pricing_source, bmrk.bmrk_pricing_source)
LEFT JOIN dn_analytic ua ON ua.asset_id = s.underlying_asset_id AND ua.asof_dt = @asof_dt AND ua.pricing_source = COALESCE(bmrk.port_pricing_source, bmrk.bmrk_pricing_source)
JOIN dn_portfolio_group_mandate pgm ON pgm.portfolio_id = bmrk.portfolio_id
JOIN #temp_mpc1_limit lim ON lim.portfolio_name = pgm.portfolio_name
GROUP BY ts.pgim_sector, pgm.portfolio_name, pgm.pag_mandate, bmrk.synthetic_look_through,
         CASE WHEN s.currency IN ('USD', 'GBP', 'EUR') THEN s.currency ELSE 'Other' END,
         s.currency,
         CASE
             WHEN d.aaa_aa_breakout = 1 THEN CASE WHEN ts.mid_value >= 29 THEN 'AAA' WHEN ts.mid_value >= 26 THEN 'AA' ELSE 'Below AA' END
             WHEN d.full_rating_breakout = 1 THEN CASE
                  WHEN ts.sec_type = 'SWAP_CDSWAP' THEN 'CDX/CDS'
                  WHEN ts.sec_type = 'SYNTH_SWAPTION' THEN 'CDX/CDS Options'
                  WHEN ts.mid_value >= 26 THEN 'AAA.AA'
                  WHEN ts.mid_value >= 23 THEN 'A'
                  WHEN ts.mid_value >= 20 THEN 'BBB'
                  WHEN ts.mid_value >= 17 THEN 'BB'
                  WHEN ts.mid_value >= 14 THEN 'B'
                  ELSE 'Below B' END
             ELSE 'NA' END,
         CASE
             WHEN COALESCE(ua.pru_wal, a.pru_wal) < 3 THEN '01-03'
             WHEN COALESCE(ua.pru_wal, a.pru_wal) < 5 THEN '03-05'
             WHEN COALESCE(ua.pru_wal, a.pru_wal) < 10 THEN '05-10'
             ELSE '10+' END,
         lim.mpc1_limit, lim.te_limit;
