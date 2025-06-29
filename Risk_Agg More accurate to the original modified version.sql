WITH a1 AS (
    SELECT 
        acv.*,
        REPLACE(acv.choiceID, ' (C)', '') AS cleaned_choiceID
    FROM DM_InvMgmt_INT.dbo.arms_calc_risk_values acv
    WHERE acv.calc_type = 'PORT'
),
a2 AS (
    SELECT 
        acv.*,
        REPLACE(acv.choiceID, ' (C)', '') AS cleaned_choiceID
    FROM DM_InvMgmt_INT.dbo.arms_calc_risk_values acv
    WHERE acv.calc_type = 'BMRK'
),
b AS (
    SELECT 
        a1.asof_dt,
        a1.choiceID,
        CASE WHEN a2.spread_pc1 IS NULL OR a2.spread_pc1 = 0 THEN 0 ELSE a1.spread_pc1 / a2.spread_pc1 * 100 END AS spc1_beta,
        CASE WHEN a2.spread_te IS NULL OR a2.spread_te = 0 THEN 0 ELSE a1.spread_te / a2.spread_te * 100 END AS oldspdte_beta,
        CASE WHEN a2.index_spread_te IS NULL OR a2.index_spread_te = 0 THEN 0 ELSE a1.index_spread_te / a2.index_spread_te * 100 END AS idxspdte_beta,
        CASE WHEN a2.index_spread_pc1 IS NULL OR a2.index_spread_pc1 = 0 THEN 0 ELSE a1.index_spread_pc1 / a2.index_spread_pc1 * 100 END AS idxspc1_beta,
        CASE WHEN a2.unified_spread_te IS NULL OR a2.unified_spread_te = 0 THEN 0 ELSE a1.unified_spread_te / a2.unified_spread_te * 100 END AS spdte_beta,
        CASE WHEN a2.unified_mpc1 IS NULL OR a2.unified_mpc1 = 0 THEN 0 ELSE a1.unified_mpc1 / a2.unified_mpc1 * 100 END AS mpc1_beta
    FROM a1
    LEFT JOIN a2
        ON a1.asof_dt = a2.asof_dt
       AND a1.cleaned_choiceID = a2.cleaned_choiceID
),
PortfolioLimits AS (
    SELECT DISTINCT
        memb_code,
        value,
        asof_dt,
        p_end_dt,
        portfolio_limit_name
    FROM dbo.portfolio_limit
    WHERE value <> 9999
),
Temp8 AS (
    SELECT 
        portfolio_limit.memb_code, 
        d.StdRiskBudget
    FROM dbo.portfolio_limit
    INNER JOIN dbo.composite_member 
        ON portfolio_limit.memb_code = composite_member.memb_code
    INNER JOIN dbo.composite 
        ON composite_member.comp_code = composite.comp_code
    LEFT JOIN (
        SELECT DISTINCT 
            portfolio_limit.value AS budget, 
            composite_member.comp_code, 
            'TRUE' AS StdRiskBudget
        FROM dbo.portfolio_limit
        INNER JOIN dbo.composite_member 
            ON portfolio_limit.memb_code = composite_member.memb_code
        INNER JOIN dbo.composite 
            ON composite_member.comp_code = composite.comp_code
        INNER JOIN (
            SELECT memb_code, 'TRUE' AS ct_std_budget 
            FROM dbo.portfolio_limit
            WHERE portfolio_limit_name = 'StandardRiskBudget' 
              AND p_end_dt = '12/31/9999'
              AND value = 1
        ) AS b 
            ON portfolio_limit.memb_code = b.memb_code
        WHERE composite.group_flag LIKE '%Z%' 
          AND portfolio_limit.portfolio_limit_name = 'TargetTE'
          AND portfolio_limit.p_end_dt = '12/31/9999'
    ) AS d 
        ON d.comp_code = composite.comp_code AND d.budget = portfolio_limit.value
    WHERE composite.group_flag LIKE '%Z%' 
      AND portfolio_limit.portfolio_limit_name = 'TargetTE'
      AND portfolio_limit.p_end_dt = '12/31/9999'
)
SELECT 
    a1.asof_dt,
    a1.cleaned_choiceID AS choiceID,
    a1.calc_type,
    a1.spread_pc1,
    a1.spread_te,
    a1.curve_te,
    a1.curve_pc1,
    a1.curve_pc2,
    a1.tips_curve_te,
    a1.curve_te_with_tips,
    a1.curr_te,
    a1.emg_shock,
    a1.industry_te,
    a1.issuer_te,
    a1.total_te,
    a1.total_sys_te,
    a1.total_non_sys_te,
    a1.e_te,
    a1.e_pc1,
    a1.e_pc2,
    a1.e_pc3,
    a1.e_sp_te,
    a1.e_fx_te,
    a1.e_cv_te,
    a1.e_sys_te,
    a1.e_non_sys_te,
    a1.jpy_curve_pc1,
    a1.jpy_curve_pc2,
    arms_calc_mv.usd_mv,
    a1.STSR,
    a1.unified_curve_te,
    a1.unified_curr_te,
    a1.unified_spread_te,
    a1.unified_cmdty_te,
    a1.unified_vol_te,
    a1.unified_residual_te,
    a1.unified_tot_sys_te,
    a1.unified_industry_te,
    a1.unified_issuer_te,
    a1.unified_tot_non_sys_te,
    a1.unified_tot_te,
    a1.unified_curve_pc1,
    a1.unified_curve_pc2,
    a1.unified_mpc1,
    a1.unified_mpc1_rate,
    a1.unified_mpc1_curr,
    a1.unified_mpc1_sprd,
    a1.unified_mpc1_cmdty,
    a1.unified_empc1,
    a1.unified_empc1_rate,
    a1.unified_empc1_curr,
    a1.unified_empc1_sprd,
    a1.unified_non_sys_te,
    Temp1.value AS Std_Flag,
    Temp2.value AS Total_Threshold,
    Temp3.value AS Syst_Threshold,
    Temp4.value AS FX_Threshold,
    Temp5.value AS Spread_Threshold,
    Temp6.value AS Rates_Threshold,
    Temp7.value AS SPC1_Threshold,
    dpgm.risk_mandate,
    Temp8.StdRiskBudget AS Std_Risk_Budget,
    b.spc1_beta,
    b.oldspdte_beta,
    b.idxspdte_beta,
    b.idxspc1_beta,
    b.spdte_beta,
    b.mpc1_beta
FROM a1
LEFT JOIN dn_portfolio_group_mandate dpgm
    ON a1.cleaned_choiceID = dpgm.portfolio_name
LEFT JOIN PortfolioLimits Temp1
    ON a1.cleaned_choiceID = Temp1.memb_code AND Temp1.asof_dt <= a1.asof_dt AND Temp1.p_end_dt > a1.asof_dt
    AND Temp1.portfolio_limit_name = 'StandardRiskBudget'
LEFT JOIN PortfolioLimits Temp2
    ON a1.cleaned_choiceID = Temp2.memb_code AND Temp2.asof_dt <= a1.asof_dt AND Temp2.p_end_dt > a1.asof_dt
    AND Temp2.portfolio_limit_name = 'TargetTE'
LEFT JOIN PortfolioLimits Temp3
    ON a1.cleaned_choiceID = Temp3.memb_code AND Temp3.asof_dt <= a1.asof_dt AND Temp3.p_end_dt > a1.asof_dt
    AND Temp3.portfolio_limit_name = 'TotalTE'
LEFT JOIN PortfolioLimits Temp4
    ON a1.cleaned_choiceID = Temp4.memb_code AND Temp4.asof_dt <= a1.asof_dt AND Temp4.p_end_dt > a1.asof_dt
    AND Temp4.portfolio_limit_name = 'CurrencyTE'
LEFT JOIN PortfolioLimits Temp5
    ON a1.cleaned_choiceID = Temp5.memb_code AND Temp5.asof_dt <= a1.asof_dt AND Temp5.p_end_dt > a1.asof_dt
    AND Temp5.portfolio_limit_name = 'SpreadTE'
LEFT JOIN PortfolioLimits Temp6
    ON a1.cleaned_choiceID = Temp6.memb_code AND Temp6.asof_dt <= a1.asof_dt AND Temp6.p_end_dt > a1.asof_dt
    AND Temp6.portfolio_limit_name = 'CurveTE'
LEFT JOIN PortfolioLimits Temp7
    ON a1.cleaned_choiceID = Temp7.memb_code AND Temp7.asof_dt <= a1.asof_dt AND Temp7.p_end_dt > a1.asof_dt
    AND Temp7.portfolio_limit_name = 'SpreadPC1'
LEFT JOIN arms_calc_mv
    ON a1.cleaned_choiceID = arms_calc_mv.choiceID AND a1.asof_dt = arms_calc_mv.asof_dt
LEFT JOIN Temp8
    ON a1.cleaned_choiceID = Temp8.memb_code
LEFT JOIN b
    ON a1.choiceID = b.choiceID AND a1.asof_dt = b.asof_dt;
