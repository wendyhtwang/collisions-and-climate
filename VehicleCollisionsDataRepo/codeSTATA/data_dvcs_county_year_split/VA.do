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

*************************VA (licensed drivers & death rate are dropped)
/*----------------------------------------------------*/
      /* [>   1.  Total 16-19   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataCSV/DVCs/VA/VA.TVC.16-19.CountySeverity.xlsx"
import excel using "`file_name'" , describe

forvalue s = 1/`r(N_worksheet)' {
    import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(`r(range_`s')') firstrow case(lower) clear
    gen year = `r(worksheet_`s')'

    tempfile newstata`s'
    save `newstata`s'', replace
}

local Nminus = `r(N_worksheet)'-1

forvalue s = 1/`Nminus' {
    append using `newstata`s'', force
}

drop licenseddrivers deathrateper1000drivers g doesnotincludevirginialice

rename whathappenedinvirginiacounti county_name
rename totalinjuries total_injuries
rename totalfatalities total_fatalities
rename totalcrashes total_total

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "total:"
replace county_name = subinstr(county_name, " county", "", .)


sort county_name year, stable
 
tempfile CSV
save `CSV', replace
/*----------------------------------------------------*/
      /* [>   2.  Total & Deer 98-15   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/VA/VA-cr-fatalities-inj-total-deer 1998-2015.xlsx"
import excel using "`file_name'" , describe
import excel using "`file_name'", allstring sheet(`r(worksheet_1)') cellrange(A4:BU102) firstrow case(lower) clear

local i=-1
foreach v of varlist b-bu {
  local lb_var : var label `v'
  local suffix = substr(`v'[1],1,1)
  local i=`i'+1
  rename `v' crashes`suffix'_`lb_var'_`i'
}

drop in 1

ren a county_name
 
gen id = _n
reshape long crashes@, i(id) j(type) string
drop id 
split type, parse(_) destring
rename (type1 type2 type3) (severity year order)
drop type
sort county_name order
replace year=year[_n-1] if year==.
drop order

reshape wide crashes, i(county_name year) j(severity) string

ren crashesI total_injury
ren crashesF total_fatal
ren crashesP total_pdo
ren crashesT total_total

tempfile crash
save `crash', replace

 
clear
local file_name = "$path/dataRAW/DVCs/VA/VA-cr-fatalities-inj-total-deer 1998-2015.xlsx"
import excel using "`file_name'" , describe
import excel using "`file_name'", allstring sheet(`r(worksheet_3)') cellrange(A4:AK102) firstrow case(lower) clear

local i=-1
foreach v of varlist b-ak {
  local lb_var : var label `v'
  local suffix = substr(`v'[1],1,1)
  local i=`i'+1
  rename `v' crashes`suffix'_`lb_var'_`i'
}

drop in 1
ren a county_name

gen id = _n
reshape long crashes@, i(id) j(type) string
drop id 
split type, parse(_) destring
rename (type1 type2 type3) (severity year order)
drop type
sort county_name order
replace year=year[_n-1] if year==.
drop order

reshape wide crashes, i(county_name year) j(severity) string

ren crashesI total_injuries
ren crashesF total_fatalities

merge 1:1 county_name year using `crash'
br if _merge != 3
drop _merge
destring total*, replace

tempfile total
save `total', replace

/* [> Deer <] */
clear
local file_name = "$path/dataRAW/DVCs/VA/VA-cr-fatalities-inj-total-deer 1998-2015.xlsx"
import excel using "`file_name'" , describe
import excel using "`file_name'", allstring sheet(`r(worksheet_5)') cellrange(A4:BT102) firstrow case(lower) clear

local i=-1
foreach v of varlist b-bt {
  local lb_var : var label `v'
  local suffix = substr(`v'[1],1,1)
  local i=`i'+1
  rename `v' crashes`suffix'_`lb_var'_`i'
}

drop in 1

ren a county_name

gen id = _n
reshape long crashes@, i(id) j(type) string
drop id 
split type, parse(_) destring
rename (type1 type2 type3) (severity year order)
drop type
sort county_name order
replace year=year[_n-1] if year==.
drop order
reshape wide crashes, i(county_name year) j(severity) string
ren crashesI deer_injury
ren crashesF deer_fatal
ren crashesP deer_pdo
ren crashesT deer_total

tempfile crash
save `crash', replace

clear
local file_name = "$path/dataRAW/DVCs/VA/VA-cr-fatalities-inj-total-deer 1998-2015.xlsx"
import excel using "`file_name'" , describe
import excel using "`file_name'", allstring sheet(`r(worksheet_7)') cellrange(A5:AK103) firstrow case(lower) clear

local i=-1
foreach v of varlist b-ak {
  local lb_var : var label `v'
  local suffix = substr(`v'[1],1,1)
  local i=`i'+1
  rename `v' crashes`suffix'_`lb_var'_`i'
}

drop in 1
ren a county_name

gen id = _n
reshape long crashes@, i(id) j(type) string
drop id 
split type, parse(_) destring
rename (type1 type2 type3) (severity year order)
drop type
sort county_name order
replace year=year[_n-1] if year==.
drop order
reshape wide crashes, i(county_name year) j(severity) string
ren crashesI deer_injuries
ren crashesF deer_fatalities

merge 1:1 county_name year using `crash'
br if _merge != 3
drop _merge
destring deer*, replace

tempfile deer
save `deer', replace

merge 1:1 county_name year using `total'
br if _merge != 3
drop _merge

tempfile 98_15
save `98_15', replace
 
/*----------------------------------------------------*/
      /* [>   3.  Total 07-19   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/VA/virginia crashes-type-fatalities-inj 2007-2019.xlsx"
import excel using "`file_name'" , describe
import excel using "`file_name'", allstring sheet(`r(worksheet_1)') cellrange(A3:AN140) firstrow case(lower) clear

local i=-1
foreach v of varlist b-an {
  local lb_var : var label `v'
  local suffix = substr(`v'[1],1,1)
  local i=`i'+1
  rename `v' crashes`suffix'_`lb_var'_`i'
}

drop in 1

ren a county_name
drop if county_name==""

gen id = _n
reshape long crashes@, i(id) j(type) string
drop id 
split type, parse(_) destring
rename (type1 type2 type3) (severity year order)
drop type
sort county_name order
replace year=year[_n-1] if year==.
drop order
reshape wide crashes, i(county_name year) j(severity) string
ren crashesI total_injury
ren crashesF total_fatal
ren crashesP total_pdo

tempfile crash
save `crash', replace

clear
local file_name = "$path/dataRAW/DVCs/VA/virginia crashes-type-fatalities-inj 2007-2019.xlsx"
import excel using "`file_name'" , describe
import excel using "`file_name'", allstring sheet(`r(worksheet_2)') cellrange(A3:AA139) firstrow case(lower) clear

local i=-1
foreach v of varlist b-aa {
  local lb_var : var label `v'
  local suffix = substr(`v'[1],1,1)
  local i=`i'+1
  rename `v' crashes`suffix'_`lb_var'_`i'
}

drop in 1

ren jurisdiction county_name

gen id = _n
reshape long crashes@, i(id) j(type) string
drop id 
split type, parse(_) destring
rename (type1 type2 type3) (severity year order)
drop type
sort county_name order
replace year=year[_n-1] if year==.
drop order
reshape wide crashes, i(county_name year) j(severity) string
ren crashesI total_injuries
ren crashesF total_fatalities

merge 1:1 county_name year using `crash'
br if _merge != 3
drop _merge
destring total*, replace


tempfile total
save `total', replace

/*----------------------------------------------------*/
      /* [>   4.  Wild animal 07-19   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/VA/virginia avoiding animal-crashes-type-fatalities-inj 2007-2019.xlsx"
import excel using "`file_name'" , describe
import excel using "`file_name'", allstring sheet(`r(worksheet_1)') cellrange(A3:AN139) firstrow case(lower) clear

local i=-1
foreach v of varlist b-an {
  local lb_var : var label `v'
  local suffix = substr(`v'[1],1,1)
  local i=`i'+1
  rename `v' crashes`suffix'_`lb_var'_`i'
}

drop in 1
ren a county_name
drop if county_name==""

gen id = _n
reshape long crashes@, i(id) j(type) string
drop id 
split type, parse(_) destring
rename (type1 type2 type3) (severity year order)
drop type
sort county_name order
replace year=year[_n-1] if year==.
drop order
reshape wide crashes, i(county_name year) j(severity) string
ren crashesI animal_injury
ren crashesF animal_fatal
ren crashesP animal_pdo

tempfile crash
save `crash', replace

clear
local file_name = "$path/dataRAW/DVCs/VA/virginia avoiding animal-crashes-type-fatalities-inj 2007-2019.xlsx"
import excel using "`file_name'" , describe
import excel using "`file_name'", allstring sheet(`r(worksheet_2)') cellrange(A3:AA140) firstrow case(lower) clear

local i=-1
foreach v of varlist b-aa {
  local lb_var : var label `v'
  local suffix = substr(`v'[1],1,1)
  local i=`i'+1
  rename `v' crashes`suffix'_`lb_var'_`i'
}

drop in 1
ren jurisdiction county_name
drop if county_name==""

gen id = _n
reshape long crashes@, i(id) j(type) string
drop id 
split type, parse(_) destring
rename (type1 type2 type3) (severity year order)
drop type
sort county_name order
replace year=year[_n-1] if year==.
drop order
reshape wide crashes, i(county_name year) j(severity) string
ren crashesI animal_injuries
ren crashesF animal_fatalities

merge 1:1 county_name year using `crash'
br if _merge != 3
drop _merge
destring animal*, replace

tempfile wild_animal
save `wild_animal', replace

/*----------------------------------------------------*/
      /* [>   5.  Deer 07-19   <] */
/*----------------------------------------------------*/
clear
set excelxlsxlargefile on
local file_name = "$path/dataRAW/DVCs/VA/virginia deer-crashes-type-fatalities-inj 2007-2019.xlsx"
import excel using "`file_name'" , describe
import excel using "`file_name'", allstring sheet(`r(worksheet_1)') cellrange(A3:BA139) firstrow case(lower) clear

local i=-1
foreach v of varlist b-ba {
  local lb_var : var label `v'
  local suffix = substr(`v'[1],1,1)
  local i=`i'+1
  rename `v' crashes`suffix'_`lb_var'_`i'
}

drop in 1

ren a county_name
drop if county_name==""

gen id = _n
reshape long crashes@, i(id) j(type) string
drop id 

split type, parse(_) destring
rename (type1 type2 type3) (severity year order)
drop type
sort county_name order
replace year=year[_n-1] if year==.
drop order
reshape wide crashes, i(county_name year) j(severity) string
ren crashesI deer_injury
ren crashesF deer_fatal
ren crashesP deer_pdo
ren crashesT deer_total

tempfile crash
save `crash', replace

clear
local file_name = "$path/dataRAW/DVCs/VA/virginia deer-crashes-type-fatalities-inj 2007-2019.xlsx"
import excel using "`file_name'" , describe
import excel using "`file_name'", allstring sheet(`r(worksheet_2)') cellrange(A3:AA139) firstrow case(lower) clear

local i=-1
foreach v of varlist b-aa {
  local lb_var : var label `v'
  local suffix = substr(`v'[1],1,1)
  local i=`i'+1
  rename `v' crashes`suffix'_`lb_var'_`i'
}

drop in 1

ren a county_name
drop if county_name==""

gen id = _n
reshape long crashes@, i(id) j(type) string
drop id 
split type, parse(_) destring
rename (type1 type2 type3) (severity year order)
drop type
sort county_name order
replace year=year[_n-1] if year==.
drop order
reshape wide crashes, i(county_name year) j(severity) string
ren crashesI deer_injuries
ren crashesF deer_fatalities

merge 1:1 county_name year using `crash'
br if _merge != 3
drop _merge

use "$working_data/VA/dvcs_VA_DEER.dta" ,replace

replace county_name = "Unknown" if county_name=="UNKNOWN"

tempfile deer
save `deer', replace
 
merge 1:1 county_name year using `total', nogenerate
merge 1:1 county_name year using `wild_animal', nogenerate

replace county_name = "UNKNOWN" if county_name=="Unknown"

tempfile 07_19
save `07_19', replace

/*----------------------------------------------------*/
      /* [>   6.  Merge with `98_15'   <] */
/*----------------------------------------------------*/
merge 1:1 county_name year using `98_15', update
br if _merge != 3
drop _merge

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "total:"
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
replace county_name = subinstr(county_name, " county", "", .)
replace county_name = "virginia beach city" if county_name  == "va. beach city"
drop if county_name==""

assert total_fatal>=0 ///
    & total_injury>=0 ///
    & total_pdo>=0 ///
    & total_fatalities>=0 ///
    & total_injuries>=0 ///
    & total_total>=0 ///
    & deer_fatal>=0 ///
    & deer_injury>=0 ///
    & deer_pdo>=0 ///
    & deer_fatalities>=0 ///
    & deer_injuries>=0 ///
    & deer_total>=0 ///
    & animal_fatal>=0 ///
    & animal_injury>=0 ///
    & animal_pdo>=0 ///
    & animal_fatalities>=0 ///
    & animal_injuries>=0 , fast // sanity check



/*----------------------------------------------------*/
      /* [>   7.  Merge with state_county_identifiers   <] */
/*----------------------------------------------------*/
* creating a balanced dataset
fillin year county_name
drop _fillin

gen state_letter_code  = "VA" // add state abbreviation

local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)
br if _merge==1
drop _merge
drop if county_name == "total" | county_name == "unknown"

order state_letter_code ///
    state_name ///
    county_name ///
    state_fips ///
    county_fips ///
    fips year


qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
compress
save "$working_data/dvcs_VA_county_year_`T1'_`T2'.dta" ,replace
