****************************************************
* 035_calc_wt.do
* Function: Calculate stabilized weights and assess covariate balance
* * df02new.dta -> df03new.dta
****************************************************

version 18.0

* 0) Log
cap log close
log using "$LOG/log_035_calc_wt.smcl", replace

****************************************************
* 1) Definitions of input and output files
****************************************************

local read_file  "$CLEAN/df02new.dta"
local write_file "$CLEAN/df03new.dta"

local loveplot  "$OUT/01_Loveplot.png"
local csplot    "$OUT/02_CommonSupport.png"
local excel_wt0 "$OUT/03_CovBalance_wt0.xlsx"
local excel_wt1 "$OUT/03_CovBalance_wt1.xlsx"

* The output directory is not present in a fresh checkout of this project.
capture mkdir "$OUT"

use "`read_file'", clear

****************************************************
* 2) Exposure and allocation factors
****************************************************

local expv intv
local covs i.jutsu i.first i.hosp

****************************************************
* 3) Sanity checks
****************************************************

foreach cmd in swbin covbalx kishess loveplot csplot {
	capture which `cmd'
	if _rc {
		di as error "`cmd' is not installed or is not on the ado-path."
		exit 199
	}
}

confirm numeric variable `expv' jutsu first hosp
assert !missing(`expv', jutsu, first, hosp)
assert inlist(`expv', 0, 1)
quietly levelsof `expv', local(grplevels)
local n_grps : word count `grplevels'
assert `n_grps' == 2

* Definitions are based on the construction of hosp in 030_define_vars.do.
* The facility name has been masked to prevent identification.
label define hosp_lbl 0 "foobar1" 1 "foobar2" 2 "foobar3" 3 "foobar4", replace
label values hosp hosp_lbl

****************************************************
* 4) Propensity score and stabilized weight
****************************************************

* Denominator: P(intv=1 | jutsu, first, hosp), standard logistic model.
* Numerator:   P(intv=1), intercept-only standard logistic model.
swbin `expv' `covs', ///
	method(logit) ///
	psden(ps_den) ///
	psnum(ps_num) ///
	sw(sw)

assert !missing(ps_den, ps_num, sw)
assert ps_den > 0 & ps_den < 1
assert ps_num > 0 & ps_num < 1
assert sw > 0

* Weight and propensity-score diagnostics.
summarize ps_den ps_num sw, detail
tabstat ps_den sw, by(`expv') ///
	statistics(n mean sd min p25 p50 p75 max) ///
	columns(statistics) format(%10.4f)

count if ps_den < 0.01 | ps_den > 0.99
di as text "N with ps_den < 0.01 or ps_den > 0.99: " as result r(N)
count if ps_den < 0.05 | ps_den > 0.95
di as text "N with ps_den < 0.05 or ps_den > 0.95: " as result r(N)

****************************************************
* 5) Assessment of covariate balance after weighting
****************************************************

* Descriptive statistics and SMDs before and after SW adjustment.
covbalx ps_den `covs', ///
	by(`expv') ///
	excel("`excel_wt0'") ///
	replace

covbalx ps_den `covs' [pweight=sw], ///
	by(`expv') ///
	excel("`excel_wt1'") ///
	replace

* Kish effective sample size overall and by intervention group.
kishess sw
kishess sw, by(`expv')

* Love plot of unadjusted and SW-adjusted SMDs.
loveplot ps_den `covs', ///
	by(`expv') wt(sw) ///
	abs denom(unadjusted) threshold(0.1) ///
	dropbase(_all) ///
	autosize ylabsize(vsmall) msize(small) ///
	name(loveplot, replace)
graph export "`loveplot'", name(loveplot) as(png) replace

* Propensity-score distributions before and after SW adjustment.
csplot ps_den, by(`expv') wt(sw) ///
	bins(20) start(0) range(0 1) ///
	yunit(percent) ///
	title("Distribution balance by intervention group") ///
	xtitle("Propensity score") ///
	xlabel(0(.2)1) ///
	xlinezero(off) ///
	nolegendtitle ///
	legsize(small) ///
	name(cs, replace)
graph export "`csplot'", name(cs) as(png) replace

****************************************************
* 6) Save the analysis dataset with stabilized weights
****************************************************

compress
label data "Define variables + stabilized weights"
save "`write_file'", replace

di as text "=== Stabilized weights and balance diagnostics done ==="

cap log close
