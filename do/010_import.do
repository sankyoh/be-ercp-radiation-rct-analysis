****************************************************
* 010_import.do
* Function: Reads CSV/Excel files and saves them as dta files
* csv/excel -> df00.dta
****************************************************

* 0) Log
cap log close
log using "$LOG\log_010_import.smcl", replace

****************************************************
* 1) Definitions of Input and Output Data Files
****************************************************

local read_file  "$RAW/Excel_data_260623.xlsx"
local write_file "$RAW/df00new.dta"
local import_excel_ops "sheet("★フロー⓪★(重複例・除外例すべて含む)") cellrange(A1:R107) clear firstrow"
// local import_delim_ops

****************************************************
* 2) Import File
****************************************************

import excel using "`read_file'", `import_excel_ops'
// import delimited using "`read_file'", `import_delim_ops'

****************************************************
* 3) Sanity Check Lv1:
*        To verify that the data is not corrupted
****************************************************

* Variable Type and Number of Lines
describe
count

* Checking for Missing IDs
// count if missing(patient_id)

* Check for Duplicate IDs
// duplicates report patient_id

* A Brief Overview of Variables
// su 省略

di "Sanity Check Lv1 completed"

****************************************************
* 4) Save as RAW data
****************************************************

compress
label data "RAW data"
save "`write_file'", replace

di "=== Import done ==="

log close
