CREATE FUNCTION dbo.fn_GetRiskValuesRaw()
RETURNS TABLE
AS
RETURN
WITH CleanedRiskValues AS (
    SELECT *,
           REPLACE(choiceID, ' (C)', '') AS cleaned_choiceID
    FROM DM_InvMgmt_INT.dbo.arms_calc_risk_values
    WHERE asof_dt >= DATEADD(YEAR, -10, GETDATE())
),
PortfolioLimits AS (
    SELECT
        memb_code,
        value,
        asof_dt,
        p_end_dt,
        portfolio_limit_name
    FROM dbo.portfolio_limit
    WHERE value <> 9999
),
StdRiskBudgetFlag AS (
    SELECT DISTINCT
        pl.memb_code,
        'TRUE' AS StdRiskBudget,
        pl.value AS budget,
        cm.comp_code
    FROM dbo.portfolio_limit pl
    JOIN dbo.composite_member cm ON pl.memb_code = cm.memb_code
    JOIN dbo.composite c ON cm.comp_code = c.comp_code
    JOIN (
        SELECT memb_code
        FROM dbo.portfolio_limit
        WHERE portfolio_limit_name = 'StandardRiskBudget'
          AND p_end_dt = '12/31/9999'
          AND value = 1
    ) AS b ON pl.memb_code = b.memb_code
    WHERE c.group_flag LIKE '%Z%'
      AND pl.portfolio_limit_name = 'TargetTE'
      AND pl.p_end_dt = '12/31/9999'
),
StdRiskBudgetComp AS (
    SELECT pl.memb_code, d.StdRiskBudget
    FROM dbo.portfolio_limit pl
    JOIN dbo.composite_member cm ON pl.memb_code = cm.memb_code
    JOIN dbo.composite c ON cm.comp_code = c.comp_code
    LEFT JOIN StdRiskBudgetFlag d ON d.comp_code = c.comp_code AND d.budget = pl.value
    WHERE c.group_flag LIKE '%Z%'
      AND pl.portfolio_limit_name = 'TargetTE'
      AND pl.p_end_dt = '12/31/9999'
),
BenchmarkBetas AS (
    SELECT 
        a1.asof_dt,
        REPLACE(a1.choiceID, ' (C)', '') AS cleaned_choiceID,
        CASE 
			WHEN ISNULL(NULLIF(a2.spread_pc1, 0), 0) = 0 THEN 0
			ELSE a1.spread_pc1 * 100.0 / a2.spread_pc1
		END AS spc1_beta,
        CASE 
			WHEN ISNULL(NULLIF(a2.spread_te, 0), 0) = 0 THEN 0
			ELSE a1.spread_te * 100.0 / a2.spread_te
		END AS oldspdte_beta,
        CASE 
			WHEN ISNULL(NULLIF(a2.index_spread_te, 0), 0) = 0 THEN 0
			ELSE a1.index_spread_te * 100.0 / a2.index_spread_te
		END AS idxspdte_beta,
        CASE 
			WHEN ISNULL(NULLIF(a2.index_spread_pc1, 0), 0) = 0 THEN 0
			ELSE a1.index_spread_pc1 * 100.0 / a2.index_spread_pc1
		END AS idxspc1_beta,
        CASE 
			WHEN ISNULL(NULLIF(a2.unified_spread_te, 0), 0) = 0 THEN 0
			ELSE a1.unified_spread_te * 100.0 / a2.unified_spread_te
		END AS spdte_beta,
        CASE 
			WHEN ISNULL(NULLIF(a2.unified_mpc1, 0), 0) = 0 THEN 0
			ELSE a1.unified_mpc1 * 100.0 / a2.unified_mpc1
		END AS mpc1_beta
    FROM DM_InvMgmt_INT.dbo.arms_calc_risk_values a1
    JOIN DM_InvMgmt_INT.dbo.arms_calc_risk_values a2
        ON a1.asof_dt = a2.asof_dt AND a1.choiceID = a2.choiceID
    JOIN dn_portfolio_group_mandate pgm
        ON REPLACE(a1.choiceID, ' (C)', '') = pgm.portfolio_name
    WHERE a1.calc_type = 'PORT'
      AND a2.calc_type = 'BMRK'
      AND a1.asof_dt >= DATEADD(YEAR, -10, GETDATE())
      AND pgm.risk_mandate IS NOT NULL
)
SELECT 
    arv.asof_dt,
    arv.cleaned_choiceID AS choiceID,
    arv.calc_type,
    arv.spread_pc1,
    arv.spread_te,
    arv.curve_te,
    arv.curve_pc1,
    arv.curve_pc2,
    arv.tips_curve_te,
    arv.curve_te_with_tips,
    arv.curr_te,
    arv.emg_shock,
    arv.industry_te,
    arv.issuer_te,
    arv.total_te,
    arv.total_sys_te,
    arv.total_non_sys_te,
    arv.e_te,
    arv.e_pc1,
    arv.e_pc2,
    arv.e_pc3,
    arv.e_sp_te,
    arv.e_fx_te,
    arv.e_cv_te,
    arv.e_sys_te,
    arv.e_non_sys_te,
    arv.jpy_curve_pc1,
    arv.jpy_curve_pc2,
    mv.usd_mv,
    arv.STSR,
    arv.unified_curve_te,
    arv.unified_curr_te,
    arv.unified_spread_te,
    arv.unified_cmdty_te,
    arv.unified_vol_te,
    arv.unified_residual_te,
    arv.unified_tot_sys_te,
    arv.unified_industry_te,
    arv.unified_issuer_te,
    arv.unified_tot_non_sys_te,
    arv.unified_tot_te,
    arv.unified_curve_pc1,
    arv.unified_curve_pc2,
    arv.unified_mpc1,
    arv.unified_mpc1_rate,
    arv.unified_mpc1_curr,
    arv.unified_mpc1_sprd,
    arv.unified_mpc1_cmdty,
    arv.unified_empc1,
    arv.unified_empc1_rate,
    arv.unified_empc1_curr,
    arv.unified_empc1_sprd,
    arv.unified_non_sys_te,
    pl_std.value AS Std_Flag,
    pl_total.value AS Total_Threshold,
    pl_syst.value AS Syst_Threshold,
    pl_fx.value AS FX_Threshold,
    pl_spread.value AS Spread_Threshold,
    pl_rates.value AS Rates_Threshold,
    pl_spc1.value AS SPC1_Threshold,
    pgm.risk_mandate,
    srb.StdRiskBudget,
    bb.spc1_beta,
    bb.oldspdte_beta,
    bb.idxspdte_beta,
    bb.idxspc1_beta,
    bb.spdte_beta,
    bb.mpc1_beta
FROM CleanedRiskValues arv
JOIN dn_portfolio_group_mandate pgm
    ON arv.cleaned_choiceID = pgm.portfolio_name
LEFT JOIN PortfolioLimits pl_std
    ON arv.cleaned_choiceID = pl_std.memb_code
    AND arv.asof_dt BETWEEN pl_std.asof_dt AND pl_std.p_end_dt
    AND pl_std.portfolio_limit_name = 'StandardRiskBudget'
LEFT JOIN PortfolioLimits pl_total
    ON arv.cleaned_choiceID = pl_total.memb_code
    AND arv.asof_dt BETWEEN pl_total.asof_dt AND pl_total.p_end_dt
    AND pl_total.portfolio_limit_name = 'TotalTE'
LEFT JOIN PortfolioLimits pl_syst
    ON arv.cleaned_choiceID = pl_syst.memb_code
    AND arv.asof_dt BETWEEN pl_syst.asof_dt AND pl_syst.p_end_dt
    AND pl_syst.portfolio_limit_name = 'CurrencyTE'
LEFT JOIN PortfolioLimits pl_fx
    ON arv.cleaned_choiceID = pl_fx.memb_code
    AND arv.asof_dt BETWEEN pl_fx.asof_dt AND pl_fx.p_end_dt
    AND pl_fx.portfolio_limit_name = 'CurrencyTE'
LEFT JOIN PortfolioLimits pl_spread
    ON arv.cleaned_choiceID = pl_spread.memb_code
    AND arv.asof_dt BETWEEN pl_spread.asof_dt AND pl_spread.p_end_dt
    AND pl_spread.portfolio_limit_name = 'SpreadTE'
LEFT JOIN PortfolioLimits pl_rates
    ON arv.cleaned_choiceID = pl_rates.memb_code
    AND arv.asof_dt BETWEEN pl_rates.asof_dt AND pl_rates.p_end_dt
    AND pl_rates.portfolio_limit_name = 'CurveTE'
LEFT JOIN PortfolioLimits pl_spc1
    ON arv.cleaned_choiceID = pl_spc1.memb_code
    AND arv.asof_dt BETWEEN pl_spc1.asof_dt AND pl_spc1.p_end_dt
    AND pl_spc1.portfolio_limit_name = 'SpreadPC1'
LEFT JOIN arms_calc_mv mv
    ON arv.cleaned_choiceID = mv.choiceID
    AND arv.asof_dt = mv.asof_dt
LEFT JOIN StdRiskBudgetComp srb
    ON srb.memb_code = arv.cleaned_choiceID
LEFT JOIN BenchmarkBetas bb
    ON bb.cleaned_choiceID = arv.cleaned_choiceID
    AND bb.asof_dt = arv.asof_dt
WHERE pgm.risk_mandate IS NOT NULL;
