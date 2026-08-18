/********************************************************************
 301_Secondary.do
 Secondary outcomes

 Group coding and estimands
   intv = 1: low-frame-rate group (A)
   intv = 0: conventional group (B; reference)

   Binary outcomes:
     Modified Poisson regression with robust variance
     Effect measure = risk ratio (A / B)

   Continuous outcomes:
     Linear regression with robust variance
     Effect measure = regression coefficient (A - B)

 Analyses
   SW-adjusted: stabilized weight sw as pweight
   Crude      : unweighted sensitivity analysis

 Analysis populations
   Binary outcomes    : all patients (do not restrict to succ == 1)
   Continuous outcomes: insertion successes only (succ == 1)

 Input : df03new.dta
 Output: Table_secondary_301.xlsx
********************************************************************/

version 18.0
set more off
set linesize 255

****************************************************
* 0) Project settings and log
****************************************************

* Allow execution either from the project root or from the do directory.
if "$PROJ" == "" {
    capture noisily do "000_config.do"
    if _rc {
        capture noisily do "../000_config.do"
    }
}

if "$PROJ" == "" {
    di as error "Project globals are not defined. Run 000_config.do first."
    exit 198
}

capture mkdir "$LOG"
capture mkdir "$OUT"

local read_file  "$CLEAN/df03new.dta"
local write_file "$OUT/Table_secondary_301.xlsx"
local log_file   "$LOG/log_301_Secondary.smcl"

* Optional overrides are useful for a non-destructive verification run.
if "$SECONDARY_OUT" != "" local write_file "$SECONDARY_OUT"
if "$SECONDARY_LOG" != "" local log_file   "$SECONDARY_LOG"

cap log close
log using "`log_file'", replace

****************************************************
* 1) Analysis variables and sanity checks
****************************************************

confirm file "`read_file'"
use "`read_file'", clear

local group intv
local wt    sw

local binvars  ae ae_dur ae_after succ
local binlabs  `""術中術後合併症" "術中合併症" "術後合併症" "挿入成功率""'

local contvars mgy time_touka gycm2
local contlabs `""空気カーマ値（mGy）" "透視時間（秒）" "面積線量（Gy・cm2）""'

confirm numeric variable `group' `wt' succ `binvars' `contvars'
assert inlist(`group', 0, 1) if !missing(`group')
assert `wt' > 0 & `wt' < .
assert !missing(`group', `wt')
foreach y of local binvars {
    assert !missing(`y')
}
foreach y of local contvars {
    assert !missing(`y') if succ == 1
}

quietly count if !missing(`group', `wt')
local n_binary_all = r(N)
quietly count if `group' == 1 & !missing(`group', `wt')
local n_binary_1 = r(N)
quietly count if `group' == 0 & !missing(`group', `wt')
local n_binary_0 = r(N)

quietly count if succ == 1 & !missing(`group', `wt')
local n_success = r(N)
quietly count if succ == 1 & `group' == 1 & !missing(`group', `wt')
local n_success_1 = r(N)
quietly count if succ == 1 & `group' == 0 & !missing(`group', `wt')
local n_success_0 = r(N)

quietly summarize `wt', meanonly
local sw_binary_all = r(sum)
quietly summarize `wt' if `group' == 1, meanonly
local sw_binary_1 = r(sum)
quietly summarize `wt' if `group' == 0, meanonly
local sw_binary_0 = r(sum)

quietly summarize `wt' if succ == 1, meanonly
local sw_success_all = r(sum)
quietly summarize `wt' if succ == 1 & `group' == 1, meanonly
local sw_success_1 = r(sum)
quietly summarize `wt' if succ == 1 & `group' == 0, meanonly
local sw_success_0 = r(sum)

foreach y of local binvars {
    assert inlist(`y', 0, 1) if !missing(`y')
}

quietly levelsof `group' if !missing(`group'), local(grplevels)
local n_grps : word count `grplevels'
assert `n_grps' == 2

* Log the analysis populations, missingness, and weight distribution.
count
tabulate `group', missing
misstable summarize `group' `wt' succ `binvars' `contvars'
summarize `wt', detail
tabstat `wt', by(`group') ///
    statistics(n sum mean sd min p25 p50 p75 max) ///
    columns(statistics) format(%12.6f)

****************************************************
* 2) Calculate descriptive statistics and model results
****************************************************

tempfile results

postfile res ///
    byte model_order outcome_order ///
    str12 model str20 outcome str12 outtype str60 outlabel ///
    double n1 n0 ev1 ev0 wn1 wn0 wev1 wev0 prop1 prop0 ///
    double mean1 sd1 med1 q11 q31 mean0 sd0 med0 q10 q30 ///
    double effect ll ul p model_n converged estimable ///
    using "`results'", replace

foreach model in sw-adjusted crude {

    local model_order = cond("`model'" == "sw-adjusted", 1, 2)

    ************************************************
    * 2a) Binary outcomes: all patients
    ************************************************

    local i = 0
    foreach y of local binvars {
        local ++i
        local ylab : word `i' of `binlabs'

        quietly count if `group' == 1 & !missing(`y', `group', `wt')
        local n1 = r(N)
        quietly count if `group' == 0 & !missing(`y', `group', `wt')
        local n0 = r(N)

        quietly count if `group' == 1 & `y' == 1 & !missing(`y', `group', `wt')
        local ev1 = r(N)
        quietly count if `group' == 0 & `y' == 1 & !missing(`y', `group', `wt')
        local ev0 = r(N)

        quietly summarize `wt' if `group' == 1 & !missing(`y', `group', `wt'), meanonly
        local wn1 = r(sum)
        quietly summarize `wt' if `group' == 0 & !missing(`y', `group', `wt'), meanonly
        local wn0 = r(sum)

        local wev1 = 0
        if `ev1' > 0 {
            quietly summarize `wt' if `group' == 1 & `y' == 1 & !missing(`y', `group', `wt'), meanonly
            local wev1 = r(sum)
        }
        local wev0 = 0
        if `ev0' > 0 {
            quietly summarize `wt' if `group' == 0 & `y' == 1 & !missing(`y', `group', `wt'), meanonly
            local wev0 = r(sum)
        }

        if "`model'" == "sw-adjusted" {
            quietly summarize `y' if `group' == 1 & !missing(`y', `group', `wt') [aweight=`wt'], meanonly
            local prop1 = r(mean)
            quietly summarize `y' if `group' == 0 & !missing(`y', `group', `wt') [aweight=`wt'], meanonly
            local prop0 = r(mean)
        }
        else {
            quietly summarize `y' if `group' == 1 & !missing(`y', `group'), meanonly
            local prop1 = r(mean)
            quietly summarize `y' if `group' == 0 & !missing(`y', `group'), meanonly
            local prop0 = r(mean)
        }

        * A zero-event group places log(RR) on the boundary; a finite RR,
        * confidence interval, and equality p-value are not estimable.
        local estimable = (`ev1' > 0 & `ev0' > 0)
        local converged = .
        local effect = .
        local ll = .
        local ul = .
        local p = .
        local model_n = `n1' + `n0'

        if `estimable' {
            if "`model'" == "sw-adjusted" {
                quietly poisson `y' ib0.`group' if !missing(`y', `group', `wt') [pweight=`wt'], vce(robust)
            }
            else {
                quietly poisson `y' ib0.`group' if !missing(`y', `group'), vce(robust)
            }

            assert e(N) == `n1' + `n0'
            local model_n = e(N)
            local converged = e(converged)

            if `converged' {
                local b = _b[1.`group']
                local se = _se[1.`group']
                local effect = exp(`b')
                local ll = exp(`b' - invnormal(0.975) * `se')
                local ul = exp(`b' + invnormal(0.975) * `se')
                local p = 2 * normal(-abs(`b' / `se'))
            }
            else {
                local estimable = 0
            }
        }
        else {
            di as text "`model' / `y': finite RR is not estimable because one group has zero events."
        }

        post res ///
            (`model_order') (`i') ///
            ("`model'") ("`y'") ("binary") ("`ylab'") ///
            (`n1') (`n0') (`ev1') (`ev0') (`wn1') (`wn0') (`wev1') (`wev0') (`prop1') (`prop0') ///
            (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) ///
            (`effect') (`ll') (`ul') (`p') (`model_n') (`converged') (`estimable')
    }

    ************************************************
    * 2b) Continuous outcomes: insertion successes
    ************************************************

    local i = 0
    foreach y of local contvars {
        local ++i
        local ylab : word `i' of `contlabs'
        local outcome_order = `i' + 4

        quietly count if succ == 1 & `group' == 1 & !missing(`y', `group', `wt')
        local n1 = r(N)
        quietly count if succ == 1 & `group' == 0 & !missing(`y', `group', `wt')
        local n0 = r(N)

        if "`model'" == "sw-adjusted" {
            quietly summarize `y' if succ == 1 & `group' == 1 & !missing(`y', `group', `wt') [aweight=`wt'], detail
            local mean1 = r(mean)
            local sd1 = r(sd)
            local med1 = r(p50)
            local q11 = r(p25)
            local q31 = r(p75)

            quietly summarize `y' if succ == 1 & `group' == 0 & !missing(`y', `group', `wt') [aweight=`wt'], detail
            local mean0 = r(mean)
            local sd0 = r(sd)
            local med0 = r(p50)
            local q10 = r(p25)
            local q30 = r(p75)

            quietly regress `y' ib0.`group' if succ == 1 & !missing(`y', `group', `wt') [pweight=`wt'], vce(robust)
        }
        else {
            quietly summarize `y' if succ == 1 & `group' == 1 & !missing(`y', `group'), detail
            local mean1 = r(mean)
            local sd1 = r(sd)
            local med1 = r(p50)
            local q11 = r(p25)
            local q31 = r(p75)

            quietly summarize `y' if succ == 1 & `group' == 0 & !missing(`y', `group'), detail
            local mean0 = r(mean)
            local sd0 = r(sd)
            local med0 = r(p50)
            local q10 = r(p25)
            local q30 = r(p75)

            quietly regress `y' ib0.`group' if succ == 1 & !missing(`y', `group'), vce(robust)
        }

        assert e(N) == `n1' + `n0'

        local b = _b[1.`group']
        local se = _se[1.`group']
        local df = e(df_r)
        local tcrit = invttail(`df', 0.025)

        local effect = `b'
        local ll = `b' - `tcrit' * `se'
        local ul = `b' + `tcrit' * `se'
        local p = 2 * ttail(`df', abs(`b' / `se'))
        local model_n = e(N)

        post res ///
            (`model_order') (`outcome_order') ///
            ("`model'") ("`y'") ("continuous") ("`ylab'") ///
            (`n1') (`n0') (.) (.) (.) (.) (.) (.) (.) (.) ///
            (`mean1') (`sd1') (`med1') (`q11') (`q31') ///
            (`mean0') (`sd0') (`med0') (`q10') (`q30') ///
            (`effect') (`ll') (`ul') (`p') (`model_n') (1) (1)
    }
}

postclose res
use "`results'", clear
sort model_order outcome_order

****************************************************
* 3) Export the two result sheets to Excel
****************************************************

local nl = char(10)
local effect_head = "効果量（95%信頼区間）" + "`nl'" + ///
    "二値項目：RR／連続項目：回帰係数"
local p_head = "p-value" + "`nl'" + "for equality"

local sw_binary_all_s : display %9.1f `sw_binary_all'
local sw_binary_1_s   : display %9.1f `sw_binary_1'
local sw_binary_0_s   : display %9.1f `sw_binary_0'
local sw_success_all_s : display %9.1f `sw_success_all'
local sw_success_1_s   : display %9.1f `sw_success_1'
local sw_success_0_s   : display %9.1f `sw_success_0'
foreach x in sw_binary_all_s sw_binary_1_s sw_binary_0_s ///
             sw_success_all_s sw_success_1_s sw_success_0_s {
    local `x' = strtrim("``x''")
}

forvalues model_order = 1/2 {

    preserve
    keep if model_order == `model_order'
    sort outcome_order

    local sheet = cond(`model_order' == 1, "SW-adjusted", "Crude")

    if `model_order' == 1 {
        putexcel set "`write_file'", sheet("`sheet'") replace
    }
    else {
        putexcel set "`write_file'", sheet("`sheet'") modify
    }

    putexcel A1 = ("副次評価項目") ///
        B1 = ("低フレームレート群") ///
        C1 = ("従来法群") ///
        D1 = ("`effect_head'") ///
        E1 = ("`p_head'")

    forvalues i = 1/`=_N' {

        local row = `i' + 1
        local label = outlabel[`i']
        local type = outtype[`i']
        local outcome_i = outcome[`i']

        local n1_i : display %9.0f n1[`i']
        local n0_i : display %9.0f n0[`i']
        local n1_i = strtrim("`n1_i'")
        local n0_i = strtrim("`n0_i'")

        if "`type'" == "binary" {
            local pct1_i : display %9.1f (100 * prop1[`i'])
            local pct0_i : display %9.1f (100 * prop0[`i'])
            local pct1_i = strtrim("`pct1_i'")
            local pct0_i = strtrim("`pct0_i'")

            if `model_order' == 1 {
                local wev1_i : display %9.1f wev1[`i']
                local wev0_i : display %9.1f wev0[`i']
                local wn1_i   : display %9.1f wn1[`i']
                local wn0_i   : display %9.1f wn0[`i']
                foreach x in wev1_i wev0_i wn1_i wn0_i {
                    local `x' = strtrim("``x''")
                }
                local desc1 = "`wev1_i'/`wn1_i' (`pct1_i'%)"
                local desc0 = "`wev0_i'/`wn0_i' (`pct0_i'%)"
            }
            else {
                local ev1_i : display %9.0f ev1[`i']
                local ev0_i : display %9.0f ev0[`i']
                local ev1_i = strtrim("`ev1_i'")
                local ev0_i = strtrim("`ev0_i'")
                local desc1 = "`ev1_i'/`n1_i' (`pct1_i'%)"
                local desc0 = "`ev0_i'/`n0_i' (`pct0_i'%)"
            }
        }
        else {
            local mean1_i : display %9.2f mean1[`i']
            local sd1_i   : display %9.2f sd1[`i']
            local mean0_i : display %9.2f mean0[`i']
            local sd0_i   : display %9.2f sd0[`i']

            if "`outcome_i'" == "time_touka" {
                local med1_i : display %9.1f med1[`i']
                local q11_i  : display %9.1f q11[`i']
                local q31_i  : display %9.1f q31[`i']
                local med0_i : display %9.1f med0[`i']
                local q10_i  : display %9.1f q10[`i']
                local q30_i  : display %9.1f q30[`i']
            }
            else {
                local med1_i : display %9.2f med1[`i']
                local q11_i  : display %9.2f q11[`i']
                local q31_i  : display %9.2f q31[`i']
                local med0_i : display %9.2f med0[`i']
                local q10_i  : display %9.2f q10[`i']
                local q30_i  : display %9.2f q30[`i']
            }

            foreach x in mean1_i sd1_i med1_i q11_i q31_i ///
                         mean0_i sd0_i med0_i q10_i q30_i {
                local `x' = strtrim("``x''")
            }

            local desc1 = "`mean1_i' (`sd1_i')" + "`nl'" + ///
                "`med1_i' [`q11_i', `q31_i']"
            local desc0 = "`mean0_i' (`sd0_i')" + "`nl'" + ///
                "`med0_i' [`q10_i', `q30_i']"
        }

        if estimable[`i'] == 0 {
            local effect_i = "推定不能†"
        }
        else {
            local b_i  : display %9.3f effect[`i']
            local ll_i : display %9.3f ll[`i']
            local ul_i : display %9.3f ul[`i']
            local b_i  = strtrim("`b_i'")
            local ll_i = strtrim("`ll_i'")
            local ul_i = strtrim("`ul_i'")

            local effect_i = "`b_i' (`ll_i' to `ul_i')"
        }

        putexcel A`row' = ("`label'") ///
            B`row' = ("`desc1'") ///
            C`row' = ("`desc0'") ///
            D`row' = ("`effect_i'")

        if missing(p[`i']) {
            putexcel E`row' = ("—")
        }
        else if p[`i'] < 0.0001 {
            putexcel E`row' = ("<0.0001")
        }
        else {
            putexcel E`row' = (p[`i'])
        }
    }

    if `model_order' == 1 {
        local note = "解析集団：二値項目はsw総計`sw_binary_all_s'（A群`sw_binary_1_s'、B群`sw_binary_0_s'）。連続項目は挿入成功例のsw総計`sw_success_all_s'（A群`sw_success_1_s'、B群`sw_success_0_s'）。" + "`nl'" + ///
            "B・C列：二値はsw加重後のn/N（小数1桁、括弧内は加重割合）。連続はsw加重の平均（標準偏差）、中央値［Q1, Q3］。" + "`nl'" + ///
            "D・E列：swをpweightとするrobust修正Poissonまたはrobust線形回帰。群効果はA群対B群。" + "`nl'" + ///
            "† 術中合併症はA群の加重イベント総計が0のため、有限のRR・95%信頼区間・p値を推定不能。"
    }
    else {
        local note = "解析集団：二値項目は全`n_binary_all'例（A群`n_binary_1'例、B群`n_binary_0'例）。連続項目は挿入成功`n_success'例（A群`n_success_1'例、B群`n_success_0'例）。" + "`nl'" + ///
            "B・C列：二値は実人数n/N（括弧内は無加重割合）。連続は無加重の平均（標準偏差）、中央値［Q1, Q3］。" + "`nl'" + ///
            "D・E列：無加重のrobust修正Poissonまたはrobust線形回帰。群効果はA群対B群。" + "`nl'" + ///
            "† 術中合併症はA群0件のため、有限のRR・95%信頼区間・p値を推定不能。"
    }

    putexcel A1:E8, font("Yu Gothic", 11, black) hcenter vcenter ///
        border(all, thin, lightgray) txtwrap
    putexcel A2:A8, left
    putexcel E2:E8, nformat("0.0000")

    putexcel G1:L5, merge font("Yu Gothic", 10, black) ///
        fpattern(solid, lightyellow) border(all, thin, lightgray) ///
        left vcenter txtwrap
    putexcel G1 = ("`note'")

    restore
}

****************************************************
* 4) Column widths and row heights
****************************************************

mata:
b = xl()
b.set_mode("open")
b.load_book(st_local("write_file"))
for (i = 1; i <= 2; i++) {
    b.set_sheet(i == 1 ? "SW-adjusted" : "Crude")
    b.set_column_width(1, 1, 23)
    b.set_column_width(2, 3, 27)
    b.set_column_width(4, 4, 34)
    b.set_column_width(5, 5, 20)
    b.set_column_width(6, 6, 3)
    b.set_column_width(7, 12, 13)
    b.set_row_height(1, 1, 62)
    b.set_row_height(2, 5, 38)
    b.set_row_height(6, 8, 52)
}
b.close_book()
end

****************************************************
* 5) Log-facing result table
****************************************************

sort model_order outcome_order
list model outcome n1 n0 ev1 ev0 effect ll ul p model_n estimable, ///
    noobs abbreviate(20)

di as text "=== Secondary outcome analysis complete ==="
di as text "Excel output: `write_file'"

cap log close