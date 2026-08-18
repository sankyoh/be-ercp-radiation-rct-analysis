/********************************************************************
 000_config.do
********************************************************************/
version 18.0
clear all
set more off
set linesize 255

* Rood directory
global PROJ "Project_Root"

global RAW    "${PROJ}/data_raw"
global CLEAN  "${PROJ}/data_clean"
global DO     "${PROJ}/do"
global LOG    "${PROJ}/log"
global OUT    "${PROJ}/output"

cd "${PROJ}"
