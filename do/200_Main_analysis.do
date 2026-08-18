/********************************************************************
 200_Main_analysis.do
 Primary outcome: insertion time (time_ins, minutes)

 Group coding and estimand
   intv = 1: low-frame-rate group (A)
   intv = 0: conventional group (B)
   difference = A - B (smaller insertion time is better)

 Non-inferiority hypothesis
   margin = 5 minutes
   H0: A - B >= 5
   H1: A - B <  5
   one-sided alpha = 0.025

 Analyses
   Primary: stabilized-weight model using sw as pweight, robust SE
   Sensitivity: unadjusted Welch analysis

 Input : df03new.dta
 Output: Table_main.xlsx
********************************************************************/

version 18.0
set more off

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

* These directories may not exist in a fresh project copy.
capture mkdir "$LOG"
capture mkdir "$OUT"

cap log close
log using "$LOG/log_200_Main_analysis.smcl", replace

****************************************************
* 1) Input, output, and analysis constants
****************************************************

local read_file  "$CLEAN/df03new.dta"
local write_file "$OUT/Table_main.xlsx"

local outcome  time_ins
local group    intv
local wt       sw
local margin   5
local alpha_ni 0.025

confirm file "`read_file'"
use "`read_file'", clear
keep if succ==1

****************************************************
* 2) Sanity checks
****************************************************

confirm numeric variable `outcome' `group' `wt'
assert !missing(`outcome', `group', `wt')
assert inlist(`group', 0, 1)
assert `wt' > 0 & `wt' < .

quietly levelsof `group', local(grplevels)
local n_grps : word count `grplevels'
assert `n_grps' == 2

* Log the weight distribution used by the primary model.
summarize `wt', detail
tabstat `wt', by(`group') statistics(n sum mean sd min p25 p50 p75 max) ///
	columns(statistics) format(%10.4f)

****************************************************
* 3) Unweighted group-specific descriptive statistics
*    Used on the Crude sheet and in the Welch analysis.
****************************************************

quietly summarize `outcome' if `group' == 1, detail
local n1   = r(N)
local m1   = r(mean)
local sd1  = r(sd)
local med1 = r(p50)
local p251 = r(p25)
local p751 = r(p75)

quietly summarize `outcome' if `group' == 0, detail
local n0   = r(N)
local m0   = r(mean)
local sd0  = r(sd)
local med0 = r(p50)
local p250 = r(p25)
local p750 = r(p75)

assert `n1' > 1 & `n0' > 1

****************************************************
* 4) SW-weighted descriptive statistics
*    aweights are used only to obtain weighted distribution summaries.
*    Their weighted means/quantiles use the same relative sw values as
*    the pweight outcome model below.
****************************************************

quietly summarize `outcome' if `group' == 1 [aweight=`wt'], detail
assert r(N) == `n1'
local wm1   = r(mean)
local wsd1  = r(sd)
local wmed1 = r(p50)
local wp251 = r(p25)
local wp751 = r(p75)

quietly summarize `outcome' if `group' == 0 [aweight=`wt'], detail
assert r(N) == `n0'
local wm0   = r(mean)
local wsd0  = r(sd)
local wmed0 = r(p50)
local wp250 = r(p25)
local wp750 = r(p75)

****************************************************
* 5) Primary analysis: SW-adjusted model
****************************************************

* The 1.intv coefficient is the weighted difference A - B.
quietly regress `outcome' ib0.`group' [pweight=`wt'], vce(robust)

assert e(N) == `n1' + `n0'
local b_sw  = _b[1.`group']
local se_sw = _se[1.`group']
local df_sw = e(df_r)

* Confirm that the model coefficient equals the displayed weighted mean
* difference (apart from numerical precision).
local wmean_diff = `wm1' - `wm0'
if abs(`b_sw' - `wmean_diff') > 1e-8 {
	di as error "Weighted mean difference and model coefficient do not agree."
	exit 459
}

* Two-sided 95% CI. Its upper limit is the one-sided 97.5% upper bound.
local tcrit_sw = invttail(`df_sw', 0.025)
local ll_sw = `b_sw' - `tcrit_sw' * `se_sw'
local ul_sw = `b_sw' + `tcrit_sw' * `se_sw'

* H0: A-B >= margin versus H1: A-B < margin.
local t_ni_sw = (`b_sw' - `margin') / `se_sw'
local p_ni_sw = ttail(`df_sw', -`t_ni_sw')

* Two-sided equality test, H0: A-B = 0.
local p_eq_sw = 2 * ttail(`df_sw', abs(`b_sw' / `se_sw'))

****************************************************
* 6) Sensitivity analysis: unadjusted Welch model
****************************************************

quietly ttest `outcome', by(`group') welch

local b_crude  = `m1' - `m0'
local se_crude = sqrt((`sd1'^2)/`n1' + (`sd0'^2)/`n0')
local df_crude = r(df_t)

local tcrit_crude = invttail(`df_crude', 0.025)
local ll_crude = `b_crude' - `tcrit_crude' * `se_crude'
local ul_crude = `b_crude' + `tcrit_crude' * `se_crude'

* H0: A-B >= margin versus H1: A-B < margin.
local t_ni_crude = (`b_crude' - `margin') / `se_crude'
local p_ni_crude = ttail(`df_crude', -`t_ni_crude')

* Two-sided equality test, H0: A-B = 0.
local p_eq_crude = 2 * ttail(`df_crude', abs(`b_crude' / `se_crude'))

****************************************************
* 7) Strings for Excel output
****************************************************

foreach x in n1 n0 {
	local `x'_s : display %9.0f ``x''
	local `x'_s = strtrim("``x'_s'")
}

foreach x in m1 sd1 m0 sd0 wm1 wsd1 wm0 wsd0 {
	local `x'_s : display %9.2f ``x''
	local `x'_s = strtrim("``x'_s'")
}

foreach x in med1 p251 p751 med0 p250 p750 ///
	wmed1 wp251 wp751 wmed0 wp250 wp750 {
	local `x'_s : display %9.1f ``x''
	local `x'_s = strtrim("``x'_s'")
}

foreach x in b_sw ll_sw ul_sw b_crude ll_crude ul_crude {
	local `x'_s : display %9.3f ``x''
	local `x'_s = strtrim("``x'_s'")
}

local head1 = "低フレームレート群" + char(10) + "（N=`n1_s'）"
local head0 = "従来法群" + char(10) + "（N=`n0_s'）"

local wdesc1 = "`wm1_s' (`wsd1_s')" + char(10) + ///
	"`wmed1_s' [`wp251_s', `wp751_s']"
local wdesc0 = "`wm0_s' (`wsd0_s')" + char(10) + ///
	"`wmed0_s' [`wp250_s', `wp750_s']"

local desc1 = "`m1_s' (`sd1_s')" + char(10) + ///
	"`med1_s' [`p251_s', `p751_s']"
local desc0 = "`m0_s' (`sd0_s')" + char(10) + ///
	"`med0_s' [`p250_s', `p750_s']"

local diff_head = "群間差 A−B (95%信頼区間)"
local pni_head = "p-value" + char(10) + "for non-inferiority"
local peq_head = "p-value" + char(10) + "for equality"

local effect_sw = "`b_sw_s' (`ll_sw_s' to `ul_sw_s')"
local effect_crude = "`b_crude_s' (`ll_crude_s' to `ul_crude_s')"

local ci_concl_sw = cond(`ul_sw' < `margin', ///
	"Conclusion by 95% CI: A群の非劣性は示されました", ///
	"Conclusion by 95% CI: A群の非劣性は示されませんでした")
local p_concl_sw = cond(`p_ni_sw' < `alpha_ni', ///
	"P-based conclusion: 非劣性は示されました", ///
	"P-based conclusion: 非劣性は示されませんでした")

local ci_concl_crude = cond(`ul_crude' < `margin', ///
	"Conclusion by 95% CI: A群の非劣性は示されました", ///
	"Conclusion by 95% CI: A群の非劣性は示されませんでした")
local p_concl_crude = cond(`p_ni_crude' < `alpha_ni', ///
	"P-based conclusion: 非劣性は示されました", ///
	"P-based conclusion: 非劣性は示されませんでした")

local note_sw = "B列とC列：sw加重の平均値と標準偏差、中央値と四分位です。Nは実人数です。" + char(10) + ///
	"D～F列：swをpweightとするrobust線形回帰。群間差=A−B、非劣性マージン=5分。" + char(10) + ///
	"`ci_concl_sw'" + char(10) + ///
	"`p_concl_sw', one-sided alpha = 0.025"

local note_crude = "B列とC列：上段は平均値と標準偏差、下段は中央値と四分位です。" + char(10) + ///
	"D～F列：Welchの2標本比較。群間差=A−B、非劣性マージン=5分。" + char(10) + ///
	"`ci_concl_crude'" + char(10) + ///
	"`p_concl_crude', one-sided alpha = 0.025"

****************************************************
* 8) Excel output: SW-adjusted and Crude sheets
****************************************************

putexcel set "`write_file'", sheet("SW-adjusted") replace
putexcel A1:F2, font("Yu Gothic", 11, black) hcenter vcenter ///
	border(all, thin, lightgray)
putexcel A2 = ("挿入時間（分）") ///
	B1 = ("`head1'") C1 = ("`head0'") D1 = ("`diff_head'") ///
	E1 = ("`pni_head'") F1 = ("`peq_head'")
putexcel B2 = ("`wdesc1'") C2 = ("`wdesc0'") ///
	D2 = ("`effect_sw'") E2 = (`p_ni_sw') F2 = (`p_eq_sw')
putexcel B1:C2, txtwrap
putexcel E1:F1, txtwrap
putexcel E2:F2, nformat("0.0000")
putexcel H1:O4, merge font("Yu Gothic", 11, black) ///
	fpattern(solid, lightyellow) border(all, thin, lightgray) ///
	left vcenter txtwrap
putexcel H1 = ("`note_sw'")

putexcel set "`write_file'", sheet("Crude") modify
putexcel A1:F2, font("Yu Gothic", 11, black) hcenter vcenter ///
	border(all, thin, lightgray)
putexcel A2 = ("挿入時間（分）") ///
	B1 = ("`head1'") C1 = ("`head0'") D1 = ("`diff_head'") ///
	E1 = ("`pni_head'") F1 = ("`peq_head'")
putexcel B2 = ("`desc1'") C2 = ("`desc0'") ///
	D2 = ("`effect_crude'") E2 = (`p_ni_crude') F2 = (`p_eq_crude')
putexcel B1:C2, txtwrap
putexcel E1:F1, txtwrap
putexcel E2:F2, nformat("0.0000")
putexcel H1:O4, merge font("Yu Gothic", 11, black) ///
	fpattern(solid, lightyellow) border(all, thin, lightgray) ///
	left vcenter txtwrap
putexcel H1 = ("`note_crude'")

* Match the reference workbook's readable column widths and row heights.
mata:
b = xl()
b.set_mode("open")
b.load_book(st_local("write_file"))
for (i = 1; i <= 2; i++) {
	b.set_sheet(i == 1 ? "SW-adjusted" : "Crude")
	b.set_column_width(1, 1, 14)
	b.set_column_width(2, 3, 28)
	b.set_column_width(4, 4, 34)
	b.set_column_width(5, 6, 25)
	b.set_column_width(7, 7, 3)
	b.set_column_width(8, 15, 14)
	b.set_row_height(1, 2, 44)
	b.set_row_height(3, 4, 22)
}
b.close_book()
end

****************************************************
* 9) Log-facing results
****************************************************

di as text "--------------------------------------------------"
di as text "Primary SW-adjusted model (A - B)"
di as result "Estimate (95% CI): `effect_sw'"
di as result "P for non-inferiority: " %6.4f `p_ni_sw'
di as result "P for equality: " %6.4f `p_eq_sw'
di as text "`ci_concl_sw'"
di as text "`p_concl_sw', one-sided alpha = 0.025"
di as text "--------------------------------------------------"
di as text "Sensitivity analysis: unadjusted Welch (A - B)"
di as result "Estimate (95% CI): `effect_crude'"
di as result "P for non-inferiority: " %6.4f `p_ni_crude'
di as result "P for equality: " %6.4f `p_eq_crude'
di as text "`ci_concl_crude'"
di as text "`p_concl_crude', one-sided alpha = 0.025"
di as text "--------------------------------------------------"
di as text "Excel output: `write_file'"

cap log close
exit
