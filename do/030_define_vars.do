****************************************************
* 030_define_vars.do
* Function: Create the variables needed for analysis
* * df01.dta -> df02.dta
****************************************************

* 0) Log
cap log close
log using "$LOG\log_030_define_vars.smcl", replace

****************************************************
* 1) Definitions of Input and Output Data Files
****************************************************

local read_file  "$CLEAN\df01new.dta"
local write_file "$CLEAN\df02new.dta"

use "`read_file'", clear

****************************************************
* 2) Definition of the Outcome Variable
****************************************************
// add commands

****************************************************
* 3) Definition of Exposure Variables
****************************************************
// add commands

****************************************************
* 4) Definition of Covariates
****************************************************
* The facility name has been masked to prevent identification.
gen     hosp = 0 if regexm(id_txt, "^foobar1"), after(id_txt)
replace hosp = 1 if regexm(id_txt, "^foobar2")
replace hosp = 2 if regexm(id_txt, "^foobar3")
replace hosp = 3 if regexm(id_txt, "^foobar4")
label variable hosp "登録施設"


****************************************************
* 5) 保存
****************************************************

compress
label data "define variables"
save "`write_file'", replace

di "=== Clean done ==="

cap log close
