WITH a2 AS (
    SELECT 
        asof_dt,
        choiceID,
        REPLACE(choiceID, ' (C) ', '') AS cleaned_choiceID,
        [calc_type],
        [spread_pc1],
        [spread_te],
        [curve_te],
        [curve_pc1],
        [curve_pc2],
        [tips_curve_te],
        [curve_te_with_tips],
        [curr_te],
        [emg_shock],
        [industry_te],
        [issuer_te],
        [total_te],
        [total_sys_te],
        [total_non_sys_te],
        [e_te],
        [e_pc1],
        [e_pc2],
        [e_pc3],
        [e_sp_te],
        [e_fx_te],
        [e_cv_te],
        [e_sys_te],
        [e_non_sys_te],
        [jpy_curve_pc1],
        [jpy_curve_pc2],
        [STSR],
        [index_spread_te],
        [index_spread_pc1],
        [unified_curve_te],
        [unified_curr_te],
        [unified_spread_te],
        [unified_cmdty_te],
        [unified_vol_te],
        [unified_residual_te],
        [unified_tot_sys_te],
        [unified_industry_te],
        [unified_issuer_te],
        [unified_tot_non_sys_te],
        [unified_tot_te],
        [unified_curve_pc1],
        [unified_curve_pc2],
        [unified_mpc1],
        [unified_mpc1_rate],
        [unified_mpc1_curr],
        [unified_mpc1_sprd],
        [unified_mpc1_cmdty],
        [unified_empc1],
        [unified_empc1_rate],
        [unified_empc1_curr],
        [unified_empc1_sprd],
        [unified_non_sys_te]
    FROM DM_InvMgmt_INT.dbo.arms_calc_risk_values
    WHERE calc_type = 'BMRK'
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
    FROM a2
    INNER JOIN DM_InvMgmt_INT.dbo.arms_calc_risk_values a1
        ON a2.asof_dt = a1.asof_dt AND a2.choiceID = a1.choiceID
    INNER JOIN dn_portfolio_group_mandate
        ON a2.cleaned_choiceID = dn_portfolio_group_mandate.portfolio_name
    WHERE a1.calc_type = 'PORT' AND a1.asof_dt >= DATEADD(YEAR, -10, GETDATE())
      AND dn_portfolio_group_mandate.risk_mandate IS NOT NULL
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
    a2.asof_dt,
    a2.cleaned_choiceID AS choiceID,
    a2.calc_type,
    a2.spread_pc1,
    a2.spread_te,
    a2.curve_te,
    a2.curve_pc1,
    a2.curve_pc2,
    a2.tips_curve_te,
    a2.curve_te_with_tips,
    a2.curr_te,
    a2.emg_shock,
    a2.industry_te,
    a2.issuer_te,
    a2.total_te,
    a2.total_sys_te,
    a2.total_non_sys_te,
    a2.e_te,
    a2.e_pc1,
    a2.e_pc2,
    a2.e_pc3,
    a2.e_sp_te,
    a2.e_fx_te,
    a2.e_cv_te,
    a2.e_sys_te,
    a2.e_non_sys_te,
    a2.jpy_curve_pc1,
    a2.jpy_curve_pc2,
    arms_calc_mv.usd_mv,
    a2.STSR,
    a2.unified_curve_te,
    a2.unified_curr_te,
    a2.unified_spread_te,
    a2.unified_cmdty_te,
    a2.unified_vol_te,
    a2.unified_residual_te,
    a2.unified_tot_sys_te,
    a2.unified_industry_te,
    a2.unified_issuer_te,
    a2.unified_tot_non_sys_te,
    a2.unified_tot_te,
    a2.unified_curve_pc1,
    a2.unified_curve_pc2,
    a2.unified_mpc1,
    a2.unified_mpc1_rate,
    a2.unified_mpc1_curr,
    a2.unified_mpc1_sprd,
    a2.unified_mpc1_cmdty,
    a2.unified_empc1,
    a2.unified_empc1_rate,
    a2.unified_empc1_curr,
    a2.unified_empc1_sprd,
    a2.unified_non_sys_te,
    Temp1.value AS Std_Flag,
    Temp2.value AS Total_Threshold,
    Temp3.value AS Syst_Threshold,
    Temp4.value AS FX_Threshold,
    Temp5.value AS Spread_Threshold,
    Temp6.value AS Rates_Threshold,
    Temp7.value AS SPC1_Threshold,
    dn_portfolio_group_mandate.risk_mandate,
    Temp8.StdRiskBudget AS Std_Risk_Budget,
    b.spc1_beta,
    b.oldspdte_beta,
    b.idxspdte_beta,
    b.idxspc1_beta,
    b.spdte_beta,
    b.mpc1_beta
FROM a2
INNER JOIN dn_portfolio_group_mandate
    ON a2.cleaned_choiceID = dn_portfolio_group_mandate.portfolio_name
LEFT JOIN PortfolioLimits Temp1
    ON a2.cleaned_choiceID = Temp1.memb_code 
    AND Temp1.asof_dt <= a2.asof_dt AND Temp1.p_end_dt > a2.asof_dt
    AND Temp1.portfolio_limit_name = 'StandardRiskBudget'
LEFT JOIN PortfolioLimits Temp2
    ON a2.cleaned_choiceID = Temp2.memb_code 
    AND Temp2.asof_dt <= a2.asof_dt AND Temp2.p_end_dt > a2.asof_dt
    AND Temp2.portfolio_limit_name = 'TargetTE'
LEFT JOIN PortfolioLimits Temp3
    ON a2.cleaned_choiceID = Temp3.memb_code 
    AND Temp3.asof_dt <= a2.asof_dt AND Temp3.p_end_dt > a2.asof_dt
    AND Temp3.portfolio_limit_name = 'TotalTE'
LEFT JOIN PortfolioLimits Temp4
    ON a2.cleaned_choiceID = Temp4.memb_code 
    AND Temp4.asof_dt <= a2.asof_dt AND Temp4.p_end_dt > a2.asof_dt
    AND Temp4.portfolio_limit_name = 'CurrencyTE'
LEFT JOIN PortfolioLimits Temp5
    ON a2.cleaned_choiceID = Temp5.memb_code 
    AND Temp5.asof_dt <= a2.asof_dt AND Temp5.p_end_dt > a2.asof_dt
    AND Temp5.portfolio_limit_name = 'SpreadTE'
LEFT JOIN PortfolioLimits Temp6
    ON a2.cleaned_choiceID = Temp6.memb_code 
    AND Temp6.asof_dt <= a2.asof_dt AND Temp6.p_end_dt > a2.asof_dt
    AND Temp6.portfolio_limit_name = 'CurveTE'
LEFT JOIN PortfolioLimits Temp7
    ON a2.cleaned_choiceID = Temp7.memb_code 
    AND Temp7.asof_dt <= a2.asof_dt AND Temp7.p_end_dt > a2.asof_dt
    AND Temp7.portfolio_limit_name = 'SpreadPC1'
LEFT JOIN arms_calc_mv
    ON a2.cleaned_choiceID = arms_calc_mv.choiceID 
    AND a2.asof_dt = arms_calc_mv.asof_dt
LEFT JOIN Temp8
    ON Temp8.memb_code = a2.cleaned_choiceID
INNER JOIN b
    ON b.choiceID = a2.choiceID AND b.asof_dt = a2.asof_dt;
