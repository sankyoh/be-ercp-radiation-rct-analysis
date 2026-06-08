*------------------------------------------------------------
* Welch-type non-inferiority analysis
* Outcome: time (Continuous variable: Insertion time)
* Group: intv  (Dichotomous variabel: 1 = Group A, 0 = Group B)
* Difference: A - B
* Non-inferiority margin: 5 minutes
* H0: A - B >= 5
* H1: A - B < 5
*------------------------------------------------------------

use df00.dta, clear

local outcome  time
local group    intv
local margin   5
local alpha_ni 0.025 // Non-inferiority is tested by two-tailed alpha=0.025

preserve

* Analysis target: Sanity Check
assert `group'==0 | `group'==1
assert !missing(`outcome')

*-----------------------------
* Group-specific summaries
*-----------------------------
quietly summarize `outcome' if `group' == 1, detail
local n1  = r(N)
local m1  = r(mean)
local sd1 = r(sd)
local v1  = r(Var)
local med1_p50 = r(p50)
local med1_p25 = r(p25)
local med1_p75 = r(p75)



quietly summarize `outcome' if `group' == 0, detail
local n0  = r(N)
local m0  = r(mean)
local sd0 = r(sd)
local v0  = r(Var)
local med0_p50 = r(p50)
local med0_p25 = r(p25)
local med0_p75 = r(p75)

*-----------------------------
* Difference: A - B
* Welch standard error
* Satterthwaite degrees of freedom
*-----------------------------
local b  = `m1' - `m0'
local se = sqrt(`v1'/`n1' + `v0'/`n0')

qui ttest time, by(intv) welch
local df = r(df_t)

*-----------------------------
* 95% CI for A - B
*-----------------------------
local tcrit = invttail(`df', 0.025)
local ll = `b' - `tcrit' * `se'
local ul = `b' + `tcrit' * `se'

*-----------------------------
* P for non-inferiority
* H0: A - B >= margin
* H1: A - B < margin
*-----------------------------
local t_ni = (`b' - `margin') / `se'
local p_ni = ttail(`df', -`t_ni')

*-----------------------------
* P for equality
* H0: A - B = 0
* H1: A - B != 0
*-----------------------------
local t_eq = `b' / `se'
local p_eq = 2 * ttail(`df', abs(`t_eq'))

*-----------------------------
* Results
* Suppress the line-by-line display of the `display` command
*     and output the results in a single batch.
*-----------------------------
quietly {
	
    noisily display "--------------------------------------------------"
    noisily display "Welch-type analysis"
    noisily display "Outcome: `outcome'"
    noisily display "Difference: Group A - Group B"
    noisily display "Non-inferiority margin: `margin' minutes"
    noisily display "--------------------------------------------------"
    noisily display "Grp A: N = " `n1' ", mean(SD)    = " %6.3f `m1' "(" %6.3f `sd1' ")"
	noisily display "               median(IQR) = " %6.1f `med1_p50' "[" %6.1f `med1_p25' ", "  %6.1f `med1_p75' "]" 
    noisily display "Grp B: N = " `n0' ", mean(SD) = " %6.3f `m0' "(" %6.3f `sd0' ")"
	noisily display "               median(IQR) = " %6.1f `med0_p50' "[" %6.1f `med0_p25' ", "  %6.1f `med0_p75' "]" 
    noisily display "--------------------------------------------------"
    noisily display "Estimate: " %6.3f `b'
    noisily display "SE      : " %6.3f `se'
    noisily display "Welch df: " %6.3f `df'
    noisily display "95% CI  : " %6.3f `ll' " to " %6.3f `ul'
    noisily display "P for non-inferiority: " %6.4f `p_ni'
    noisily display "P for equality       : " %6.4f `p_eq'
    noisily display "--------------------------------------------------"

    if `ul' < `margin' {
        noisily display "Conclusion by 95% CI: Group A is considered non-inferior to Group B."
    }
    else {
        noisily display "Conclusion by 95% CI: Non-inferiority of Group A has not been demonstrated."
    }

    if `p_ni' < `alpha_ni' {
        noisily display "P-based conclusion: Non-inferior, one-sided alpha = 0.025"
    }
    else {
        noisily display "P-based conclusion: Non-inferiority has not been demonstrated, one-sided alpha = 0.025"
    }

}

restore