/*******************************************************************************
Program: data_dvcs_county_year.do
Current Lead:  Siyue Ouyang
Major Versions/Revisions:
07/01/2020 [Siyue Ouyang]: created
07/08/2020 [Siyue Ouyang]: code style change
07/13/2020 [Siyue Ouyang]: add more states
07/15/2020 [Siyue Ouyang]: make every single state data ready-to-use, add more states
07/26/2020 [Siyue Ouyang]: add data in ~dataRAW, update
*******************************************************************************/
/**********************************************************************/
/*  SECTION 0: root directory
    Notes: */
/**********************************************************************/
cap log close
clear all
set more off, permanently
set matsize 11000
set maxvar 32767
set scheme s1mono

confirmdir "F:/GDrive/"
if r(confirmdir) == "0" {
  local rootDir = "F:/GDrive/"
}

confirmdir "E:/GDrive/"
if r(confirmdir) == "0" {
  local rootDir = "E:/GDrive/"
}

confirmdir "D:/GoogleDrive/"
if r(confirmdir) == "0" {
  local rootDir = "D:/GoogleDrive/"
}
confirmdir "C:/GoogleDrive/"
if r(confirmdir) == "0" {
  local rootDir = "C:/GoogleDrive/"
}
confirmdir "/Users/air/Google Drive/"
if r(confirmdir) == "0" {
  local rootDir = "/Users/air/Google Drive/"
}


global path "`rootDir'/WolvesImpacts/"

global working_data "$path/dataSTATA/intermediate/collisions/"

/*-----------------End of SECTION 0: root directory --------------*/

/*-------------------------
  To Do:
     - [1] derive dta files for all the states
     - [2] merge dta files
-------------------------*/

/*----------------------------------------------------*/
      /* [>   1.  derive dta for 49 states in the folder (~/dataCSV/DVCs/) <] */
/*----------------------------------------------------*/

*************************MA (all data were kept)

************************county severity (USED)
/*----------------------------------------------------*/
      /* [>   1.  Deer 02-13   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/MA/MA.DeerCrash.2002-2013.CountySeverity.Conard.xls"
import excel using "`file_name'", cellrange(A9:N69) firstrow case(lower) clear

drop in 1

ren yearnumeric crashseverity
ren b county_name
foreach v of varlist c-n {
  local lb_var : var label `v'
  rename `v' crashes`lb_var'
}

replace crashseverity = crashseverity[_n-1] if crashseverity==""

replace crashseverity = "deer_fatal" if crashseverity == "Fatal injury"
replace crashseverity = "deer_injury" if crashseverity == "Non-fatal injury"
replace crashseverity = "deer_pdo" if crashseverity == "Property damage only (none injured)"
replace crashseverity = "deer_not_reported" if crashseverity == "Not Reported"
replace crashseverity = "deer_unknown" if crashseverity == "Unknown"

replace county_name = "statewide" if county_name == "Fatal injury"
replace county_name = "statewide" if county_name == "Non-fatal injury"
replace county_name = "statewide" if county_name == "Property damage only (none injured)"
replace county_name = "statewide" if county_name == "Not Reported"
replace county_name = "statewide" if county_name == "Unknown"
 
gen id = _n
reshape long crashes, i(id) j(year)
drop id
reshape wide crashes, i(county_name year) j(crashseverity) string
renpfix crashes 


foreach var of varlist deer_fatal deer_injury deer_pdo  {
    replace `var'= 0 if `var'==.
}

egen deer_total = rowtotal(deer_*)
* drop deer_not_reported deer_unknown

tempfile deer
save `deer', replace

/*----------------------------------------------------*/
      /* [>   2.  Total 02-19  <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/MA/MA.TotalCrash.2002-2018.CountySeverity.Conard.xlsx"
import excel using "`file_name'" , describe
import excel using "`file_name'", cellrange(:D1240) firstrow case(lower) clear

rename countyname county_name
replace county_name=county_name[_n-1] if county_name==""
replace crashseverity=crashseverity[_n-1] if crashseverity==""

replace crashseverity= "total_not_reported" if  crashseverity == "Not Reported"
replace crashseverity= "total_invalid_report" if  crashseverity == "Reported but invalid"
replace crashseverity= "total_unknown" if  crashseverity == "Unknown"
replace crashseverity= "total_fatal" if crashseverity == "Fatal injury"
replace crashseverity= "total_injury" if crashseverity == "Non-fatal injury"
replace crashseverity= "total_pdo" if crashseverity == "Property damage only (none injured)"

reshape wide crashcount, i(county_name year) j(crashseverity) string
renpfix crashcount
destring year, replace

foreach var of varlist total_fatal total_injury total_pdo  {
    replace `var'= 0 if `var'==.
}

egen total_total = rowtotal(total_*)
drop total_not_reported total_invalid_report total_unknown


/*----------------------------------------------------*/
      /* [>   3.  Merge with deer   <] */
/*----------------------------------------------------*/
merge 1:1 county_name year using `deer'
br if _merge !=3
drop _merge

gen state_letter_code  = "MA" // add state abbreviation

assert total_fatal>=0 ///
    & total_injury>=0 ///
    & total_pdo>=0 ///
    & deer_fatal>=0 ///
    & deer_injury>=0 ///
    & deer_pdo>=0 , fast // sanity check

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1

/*----------------------------------------------------*/
      /* [>   4. Merge with  state_county_identifiers <] */
/*----------------------------------------------------*/
local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)
br if _merge==1
drop _merge
drop if county_name == "statewide"

order state_letter_code ///
    state_name ///
    county_name ///
    state_fips ///
    county_fips ///
    fips year

sort state_letter_code ///
    state_name ///
    county_name ///
    state_fips ///
    county_fips ///
    fips year

/* [> imputation <] */
foreach var of varlist deer_fatal-deer_pdo  {
    replace `var'= 0 if `var'==. & year>=2002 & year<=2013
}


qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
compress
save "$working_data/dvcs_MA_county_year_`T1'_`T2'.dta" ,replace
