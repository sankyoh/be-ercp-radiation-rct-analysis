/*
服部先生＠消化器内科

Non-inferiority test

When mgn = -5,  estimated samplesize = 39/arm
When mgn = -10, estimated samplesize = 13/arm

*/

set seed 12345
local samh = 50 // samle size per group
local smps = `samh'*2 
local n    = 10000 // N. of simulation
local mgn  = -5 // margin for NIS

/*****
Result tabel
*****/
capture frame create results
frame change results
	clear
	set obs `n'
	gen ll  = .
	gen pow = .
frame change default

/*****
Simulation
*****/
forvalues i=1/`n'{
	qui{
	clear
	set obs `smps'
	gen     x = 0 in 1/`samh'
	replace x = 1 if x==.
	gen     r = rnormal(15.1967, 11.775) if x==0
	replace r = rnormal(13.7467, 10.874) if x==1
	ttest r, by(x) welch
	local ll = `r(mu_1)' - `r(mu_2)' - invt(`r(df_t)', 0.975)*`r(se)'
	local ul = `r(mu_1)' - `r(mu_2)' + invt(`r(df_t)', 0.975)*`r(se)'
	}
	
/*****
Contain results
*****/
	frame change results
		qui{
		replace ll  = `ll' in `i'
		replace pow = 1 if `ll' >  `mgn' in `i'
		replace pow = 0 if `ll' <= `mgn' in `i'
		}
	frame change default
}

/*****
View results
*****/
frame change results
sum	

exit