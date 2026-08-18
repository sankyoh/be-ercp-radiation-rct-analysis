****************************************************
* 02_clean.do
* Function: Format and save data into an analyzable dataset
* * df00.dta -> df01.dta
****************************************************

* 0) Log
cap log close
log using "$LOG\log_020_clean.smcl", replace

****************************************************
* 1) Definitions of Input and Output Data Files
****************************************************

local read_file  "$RAW\df00new.dta"
local write_file "$CLEAN\df01new.dta"

use "`read_file'", clear

****************************************************
* 2) Check ID variable
****************************************************

rename No登録日順 id
* Is the `id` missing?
count if missing(id)
assert id!=.

* Is the ID unique?
isid id

****************************************************
* 3) Trimming a String variable
****************************************************
// 余計な空白が混ざることがあるため、先に除去しておく
// 文字列変数から数値に変換できるときは、数値に変換する。
quietly ds, has(type string)
local strings `r(varlist)'
foreach v of local strings {
	replace `v' = strtrim(`v') if !missing(`v')
	cap noisily destring `v', replace
}

****************************************************
* 4) Shorten variable names and add variable labels
****************************************************
* variable name

drop   No
rename C         id_txt
rename 割付       intv_txt
rename 登録日     date_txt
drop   識別子
rename 術式      jutsu_txt
rename 初回か2回目以降か first_txt
rename 内視鏡挿入成功 succ_txt
rename 挿入時間分 time_ins
rename 空気カーマ値mGy mgy
rename 透視時間秒 time_touka
rename 面積線量Gycm2 gycm2
rename 術中術後合併症 ae_txt
rename 術中合併症有無 ae_dur_txt
rename 内容と重症度ASGE asge_dur_txt
rename 術後合併症有無 ae_after_txt
rename R            asge_after_txt

****************************************************
* 5) Fixing variables that should be continuous
*                but have been stored as strings.
* String variable -> Continuous variable
****************************************************
ds, has(type string) // display for debug

* date
gen date = date(date_txt, "MDY"), after(date_txt)
format date %td
drop date_txt
label variable date "登録日"

****************************************************
* 6) Assigning value labels to categorical variables
* This is probably the most annoying part… orz
****************************************************
// add commands

****************************************************
* 7) Fixing variables that should be categorical
*                but have been stored as strings.
* String variable -> Categorical variable
* This is probably the most annoying part… orz
****************************************************
ds, has(type string)
fre `r(varlist)' // display for debug

* intv
label define intv 0 "従来群B" 1 "低フレームレートA"
gen     intv = 0 if intv_txt=="従来群（B）", after(intv_txt)
replace intv = 1 if intv_txt=="低フレームレート群（A）"
replace intv = . if intv_txt==""
label values intv intv
label variable intv "Intervention"
// tab intv* // for debug
drop intv_txt

* jutsu
label define jutsu 0 "PD" 1 "RY(胃あり)" 2 "RY(胃なし)"
gen     jutsu = 0 if jutsu_txt == "PD", after(jutsu_txt)
replace jutsu = 1 if jutsu_txt == "RY（胃あり）"
replace jutsu = 2 if jutsu_txt == "RY（胃なし）"
replace jutsu = . if jutsu_txt == ""
label values jutsu jutsu
label variable jutsu "術式"
// tab jutsu* // for debug
drop jutsu_txt

* first
label define first 0 "初回" 1 "2回目以降"
gen     first = 0 if first_txt == "初回", after(first_txt)
replace first = 1 if first_txt == "2回目以降"
replace first = . if first_txt == ""
label values first first
label variable first "初回 or 2回目以降"
// tab first* // for debug
drop first_txt

* succ
label define succ 0 "失敗" 1 "成功"
gen     succ = 0 if succ_txt == "失敗", after(succ_txt)
replace succ = 1 if succ_txt == "成功"
replace succ = . if succ_txt == ""
label values succ succ
label variable succ "内視鏡挿入成功"
// tab succ* // for debug
drop succ_txt

* ae
label define ny 0 "no" 1 "yes"
gen     ae = 0 if ae_txt == "無", after(ae_txt)
replace ae = 1 if ae_txt == "有"
replace ae = . if ae_txt == ""
label values ae ny
label variable ae "術中術後合併症"
// tab ae ae_txt // for debug
drop ae_txt

* ae_dur
gen     ae_dur = 0 if ae_dur_txt == "なし", after(ae_dur_txt)
replace ae_dur = 1 if ae_dur_txt == "あり"
replace ae_dur = . if ae_dur_txt == ""
label values ae_dur ny
label variable ae_dur "術中合併症"
// tab ae_dur ae_dur_txt // for debug
drop ae_dur_txt

* ae_after
gen     ae_after = 0 if ae_after_txt == "なし", after(ae_after_txt)
replace ae_after = 1 if ae_after_txt == "あり"
replace ae_after = . if ae_after_txt == ""
label values ae_after ny
label variable ae_after "術後合併症"
// tab ae_after ae_after_txt // for debug
drop ae_after_txt

****************************************************
* 8)　Sanity Check Lv2
****************************************************
* Checking Variable Types
des

****************************************************
* 9) Identifying Missing Data
****************************************************
misstable summarize

* Creating a missing value flag
/*
foreach v in bmi sbp fev1 cv_time {
    gen byte miss_`v' = missing(`v')         // 1 if missing
    label values miss_`v' miss01
    label variable miss_`v' "`v' missingness"
}
*/

****************************************************
* 10) Save as CLEAN data
****************************************************
* Final Check
codebook

compress
label data "After Cleaning"
save "`write_file'", replace

di "=== Clean done ==="

cap log close
