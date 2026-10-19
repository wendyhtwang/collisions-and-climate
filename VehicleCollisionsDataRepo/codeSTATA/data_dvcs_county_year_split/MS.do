/*******************************************************************************
Program: data_dvcs_county_year.do
Current Lead:  Siyue Ouyang
Major Versions/Revisions:
07/01/2020 [Siyue Ouyang]: created
07/08/2020 [Siyue Ouyang]: code style change
07/13/2020 [Siyue Ouyang]: add more states
07/15/2020 [Siyue Ouyang]: make every single state data ready-to-use, add more states
07/26/2020 [Siyue Ouyang]: add data in ~dataRAW, update
11/08/2020 [Owen Shao]: add TVC from dataCSV, update
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

*************************MS (all data were kept)
/*----------------------------------------------------*/
	 /* [>   1.1  TVC 05-16  <] */
clear
local file_name = "$path/dataCSV/DVCs/MS/MS.TVC.2005-2016.County.xlsx"
import excel using "`file_name'" , describe
import excel using "`file_name'", allstring sheet(`r(worksheet_1)') cellrange(A1:F85) firstrow case(lower) clear

foreach v of varlist b-f {
  local lb_var : var label `v'
  local suffix = `v'[1]
  rename `v' crashes`lb_var'
}

// destring b_2005-f_2009,replace
// gather b_2005-f_2009, variable(type) value(value)
// gen str12 year = substr(type, -4, .) 
// ren value total_total

ren trafficcrashesinmississippi county_name 

gen id = _n
reshape long crashes, i(id) j(year)
drop id

ren crashes total_total
destring total_total , replace 
sort county_name year, stable

tempfile 05_09_TVC
save `05_09_TVC', replace
 
************************
import excel using "`file_name'" , describe
import excel using "`file_name'", allstring sheet(`r(worksheet_2)') cellrange(A1:H86) firstrow case(lower) clear

foreach v of varlist b-h {
  local lb_var : var label `v'
  local suffix = `v'[1]
  rename `v' crashes`lb_var'
}

// destring b_2010-h_2016,replace
// gather b_2010-h_2016, variable(type) value(value)
// gen str12 year = substr(type, -4, .) 
// ren value total_total
// drop type

ren trafficcrashesinmississippi county_name 
gen id = _n
reshape long crashes, i(id) j(year)
drop id

ren crashes total_total
destring total_total , replace 
sort county_name year, stable


tempfile 10_16_TVC
save `10_16_TVC', replace

append using  `05_09_TVC' ,force

tempfile 05_16_TVC
save `05_16_TVC', replace

/*----------------------------------------------------*/
      /* [>   1.2  Deer DVC 05-16   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataCSV/DVCs/MS/MS.DVC.2005-2016.CountySeverity.xlsx"
import excel using "`file_name'" , describe
import excel using "`file_name'", allstring sheet(`r(worksheet_1)') cellrange(A1:N86) firstrow case(lower) clear
 

foreach v of varlist b-n {
  local lb_var : var label `v'
  local suffix = `v'[1] 
  rename `v' crashes`v'_`suffix'_`lb_var'
}

ren trafficcrashesinmississippii county_name
 
drop in 1
reshape long crashes@, i(county_name) j(type) string 

sort county_name type
gen str12 year = substr(type, -4, .) if ustrregexm(type, "([0-9])")==1 
replace year=year[_n-1] if year==""
replace type = substr(type,3,1)

reshape wide crashes , i(county_name year) j(type) string

rename crashesI deer_injury
rename crashesK deer_fatal
rename crashesO deer_pdo
destring year-deer_pdo, replace

tempfile 05_09
save `05_09', replace

************************
import excel using "`file_name'" , describe
import excel using "`file_name'", allstring sheet(`r(worksheet_2)') cellrange(A1:K87) firstrow case(lower) clear

foreach v of varlist b-k {
  local lb_var : var label `v'
  local suffix = `v'[1]
  rename `v' crashes`v'_`suffix'_`lb_var'
} 
drop in 1/2
ren trafficcrashesinmississippii county_name

reshape long crashes@, i(county_name) j(type) string 

sort county_name type
gen str12 year = substr(type, -4, .) if ustrregexm(type, "([0-9])")==1 
replace year=year[_n-1] if year==""
replace type = substr(type,3,1)

reshape wide crashes , i(county_name year) j(type) string

rename crashesI deer_injury
rename crashesK deer_fatal
rename crashesO deer_pdo
destring year-deer_pdo, replace

tempfile 10_13
save `10_13', replace
 
************************
import excel using "`file_name'" , describe
import excel using "`file_name'", allstring sheet(`r(worksheet_3)') cellrange(A1:J87) firstrow case(lower) clear

foreach v of varlist b-j {
  local lb_var : var label `v'
  local suffix = `v'[1]
  rename `v' crashes`v'_`suffix'_`lb_var'
}

drop in 1/2
ren trafficcrashesinmississippii county_name

reshape long crashes@, i(county_name) j(type) string 

sort county_name type
gen str12 year = substr(type, -4, .) if ustrregexm(type, "([0-9])")==1 
replace year=year[_n-1] if year==""
replace type = substr(type,3,1)

reshape wide crashes , i(county_name year) j(type) string

rename crashesI deer_injury
rename crashesK deer_fatal
rename crashesO deer_pdo
destring year-deer_pdo, replace

append using `10_13' `05_09'  ,force

merge 1:1 county_name year using "`05_16_TVC'", nogenerate 
assert(1 3)


tempfile deer
save `deer', replace

assert  deer_fatal>=0 ///
    & deer_injury>=0 ///
    & deer_pdo>=0, fast // sanity check

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "total:"
replace county_name = "st. francois" if county_name == "st. francios"
replace county_name = subinstr(county_name, " county", "", .)
drop if county_name==""

gen state_letter_code  = "MS" // add state abbreviation


/*----------------------------------------------------*/
      /* [>   2.  Merge with state_county_identifiers   <] */
/*----------------------------------------------------*/
local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'" ,keep(1 3) 
br if _merge==1
drop _merge

drop if county_name=="invalid code"
drop if county_name=="non-officer"
drop if county_name=="total"

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
    fips year, stable

/* [> imputation <] */
foreach var of varlist total_total deer_injury deer_fatal deer_pdo  {
    replace `var'= 0 if `var'==.
}

egen deer_total = rowtotal(deer_*)

qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
compress
save "$working_data/dvcs_MS_county_year_`T1'_`T2'.dta" ,replace 