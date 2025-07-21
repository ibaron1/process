DROP PROCEDURE IF EXISTS usp_GetSectorBreakoutSummary;
GO

CREATE PROCEDURE usp_GetSectorBreakoutSummary
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    -- 1. Get max asof_dt
    DECLARE @max_asof_dt DATE;
    SELECT @max_asof_dt = MAX(asof_dt)
    FROM dn_load_status WITH (NOLOCK)
    WHERE end_time IS NOT NULL;

    -- 2. Pre-filter security_ts
    DROP TABLE IF EXISTS #filtered_security_ts;
    SELECT asset_id, asof_dt, pgim_sector, mid_value
    INTO #filtered_security_ts
    FROM dn_security_ts WITH (NOLOCK)
    WHERE asof_dt = @max_asof_dt;

    -- 3. Pre-classify sectors
    DROP TABLE IF EXISTS #temp_breakout_define;
    SELECT DISTINCT
           pgim_sector,
           CASE WHEN pgim_sector IN ('High Yield', 'Investment Grade Corp', 'Emerging Markets', 'Bank Loans') THEN 1 ELSE 0 END AS full_rating_breakout,
           CASE WHEN pgim_sector IN ('Asset Backed Securities', 'RMBS Credit', 'CMBS', 'CLO') THEN 1 ELSE 0 END AS aaa_aa_breakout
    INTO #temp_breakout_define
    FROM #filtered_security_ts;

    -- 4. Portfolio limits
    DROP TABLE IF EXISTS #temp_mpc1_limit;
    SELECT CAST(memb_code AS VARCHAR(50)) AS portfolio_name,
           SUM(CASE WHEN portfolio_limit_name = 'SpreadPC1' THEN value ELSE 0 END) AS mpc1_limit,
           SUM(CASE WHEN portfolio_limit_name = 'TotalTE' THEN value ELSE 0 END) AS te_limit
    INTO #temp_mpc1_limit
    FROM portfolio_limit WITH (NOLOCK)
    WHERE p_end_dt = '9999-12-31'
      AND portfolio_limit_name IN ('SpreadPC1', 'TotalTE')
    GROUP BY memb_code;

    -- 5. Filter port_bmrk_position
    DROP TABLE IF EXISTS #filtered_position;
    SELECT *,
           COALESCE(port_pricing_source, bmrk_pricing_source) AS resolved_pricing_source
    INTO #filtered_position
    FROM dn_port_bmrk_position WITH (NOLOCK, INDEX(0))
    WHERE asof_dt = @max_asof_dt;

    -- 6. Pre-join analytic and underlying
    DROP TABLE IF EXISTS #joined_analytic;
    SELECT a.asset_id, a.asof_dt, a.pricing_source, a.oas, a.pru_wal,
           ua.asset_id AS u_asset_id, ua.pru_wal AS u_pru_wal
    INTO #joined_analytic
    FROM dn_analytic a WITH (NOLOCK)
    LEFT JOIN dn_analytic ua WITH (NOLOCK)
           ON ua.asset_id = (SELECT underlying_asset_id FROM dn_security WHERE asset_id = a.asset_id)
          AND ua.asof_dt = a.asof_dt
          AND ua.pricing_source = a.pricing_source
    WHERE a.asof_dt = @max_asof_dt;

    -- 7. Final aggregation
    SELECT
           s.pgim_sector,
           pg.portfolio_name,
           pg.pag_mandate,
           p.synthetic_look_through,
           CASE WHEN sec.currency IN ('USD', 'GBP', 'EUR') THEN sec.currency ELSE 'Other' END AS currency_group,
           sec.currency,

           CASE
               WHEN bd.aaa_aa_breakout = 1 THEN
                   CASE WHEN s.mid_value >= 29 THEN 'AAA'
                        WHEN s.mid_value >= 26 THEN 'AA'
                        ELSE 'Below AA' END
               WHEN bd.full_rating_breakout = 1 THEN
                   CASE WHEN sec.sec_type = 'SWAP_CDSWAP' THEN 'CDX/CDS'
                        WHEN sec.sec_type = 'SYNTH_SWAPTION' THEN 'CDX/CDS Options'
                        WHEN s.mid_value >= 26 THEN 'AAA.AA'
                        WHEN s.mid_value >= 23 THEN 'A'
                        WHEN s.mid_value >= 20 THEN 'BBB'
                        WHEN s.mid_value >= 17 THEN 'BB'
                        WHEN s.mid_value >= 14 THEN 'B'
                        ELSE 'Below B' END
               ELSE 'NA' END AS rating,

           CASE
               WHEN COALESCE(a.u_pru_wal, a.pru_wal) < 3 THEN '01-03'
               WHEN COALESCE(a.u_pru_wal, a.pru_wal) < 5 THEN '03-05'
               WHEN COALESCE(a.u_pru_wal, a.pru_wal) < 10 THEN '05-10'
               ELSE '10+' END AS wal_bucket,

           l.mpc1_limit,
           l.te_limit,

           SUM(p.port_pct_mv) AS port_mv,
           SUM(p.bmrk_pct_mv) AS bmrk_mv,
           SUM(p.port_pct_adj_nmv_mv) AS port_nmv,
           SUM(p.bmrk_pct_adj_nmv_mv) AS bmrk_nmv,
           SUM(p.port_unified_mpc1_sprd_contrib) AS port_mpc1,
           SUM(p.bmrk_unified_mpc1_sprd_contrib) AS bmrk_mpc1,
           SUM(p.port_unified_rec_sprd_contrib) AS port_rec,
           SUM(p.bmrk_unified_rec_sprd_contrib) AS bmrk_rec,
           SUM(p.port_spread_dur_contrib) AS port_spread_dur,
           SUM(p.bmrk_spread_dur_contrib) AS bmrk_spread_dur,

           CASE WHEN SUM(p.port_pct_adj_nmv_mv) = 0 THEN 0
                ELSE SUM(p.port_pct_adj_nmv_mv * a.oas) / (SUM(p.port_pct_mv) + 0.0000001) END AS port_oas,

           CASE WHEN SUM(p.bmrk_pct_adj_nmv_mv) = 0 THEN 0
                ELSE SUM(p.bmrk_pct_adj_nmv_mv * a.oas) / (SUM(p.bmrk_pct_mv) + 0.0000001) END AS bmrk_oas

    FROM #filtered_security_ts s
    JOIN dn_security sec WITH (NOLOCK) ON sec.asset_id = s.asset_id
    JOIN #temp_breakout_define bd ON bd.pgim_sector = s.pgim_sector
    JOIN #filtered_position p ON p.asset_id = s.asset_id AND p.asof_dt = s.asof_dt
    JOIN #joined_analytic a ON a.asset_id = s.asset_id AND a.asof_dt = s.asof_dt AND a.pricing_source = p.resolved_pricing_source
    JOIN dn_portfolio_group_mandate pg WITH (NOLOCK) ON pg.portfolio_id = p.portfolio_id
    JOIN #temp_mpc1_limit l ON l.portfolio_name = pg.portfolio_name
    GROUP BY
           s.pgim_sector,
           pg.portfolio_name,
           pg.pag_mandate,
           p.synthetic_look_through,
           CASE WHEN sec.currency IN ('USD', 'GBP', 'EUR') THEN sec.currency ELSE 'Other' END,
           sec.currency,
           CASE
               WHEN bd.aaa_aa_breakout = 1 THEN CASE WHEN s.mid_value >= 29 THEN 'AAA'
                                                    WHEN s.mid_value >= 26 THEN 'AA'
                                                    ELSE 'Below AA' END
               WHEN bd.full_rating_breakout = 1 THEN CASE WHEN sec.sec_type = 'SWAP_CDSWAP' THEN 'CDX/CDS'
                                                         WHEN sec.sec_type = 'SYNTH_SWAPTION' THEN 'CDX/CDS Options'
                                                         WHEN s.mid_value >= 26 THEN 'AAA.AA'
                                                         WHEN s.mid_value >= 23 THEN 'A'
                                                         WHEN s.mid_value >= 20 THEN 'BBB'
                                                         WHEN s.mid_value >= 17 THEN 'BB'
                                                         WHEN s.mid_value >= 14 THEN 'B'
                                                         ELSE 'Below B' END
               ELSE 'NA' END,
           CASE
               WHEN COALESCE(a.u_pru_wal, a.pru_wal) < 3 THEN '01-03'
               WHEN COALESCE(a.u_pru_wal, a.pru_wal) < 5 THEN '03-05'
               WHEN COALESCE(a.u_pru_wal, a.pru_wal) < 10 THEN '05-10'
               ELSE '10+' END,
           l.mpc1_limit,
           l.te_limit;
END;
GO
