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

*************************NH (all data were kept)
/*----------------------------------------------------*/
      /* [>   1.  Total crash   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/NH/NH.Total&Animal.2002-2013.CountySeverity.Harmon.xlsx"
import excel using "`file_name'" , describe
import excel using "`file_name'", allstring sheet(`r(worksheet_1)') cellrange(`r(range_`s')') firstrow case(lower) clear

foreach v of varlist fatal-an {
    local lb_var : var label `v'
    local var_nam = subinstr("`lb_var'"," ","_", .)
    rename `v'  total_`var_nam'
}

 
reshape long total_@, i(county) j(year) string
gen severity = substr(year,6,.)
replace year =  substr(year,1,4)

// spread severity total_
reshape wide total_, i(county year) j(severity) string
 
ren total_Fatal total_fatal
ren total_Injury total_injury
ren total_PDO total_pdo
destring year, replace 


tempfile total_crash
save `total_crash', replace

/*----------------------------------------------------*/
      /* [>   2.  Total people   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/NH/NH.Total&Animal.2002-2013.CountySeverity.Harmon.xlsx"
import excel using "`file_name'" , describe
import excel using "`file_name'", allstring sheet(`r(worksheet_2)') cellrange(`r(range_`s')') firstrow case(lower) clear

foreach v of varlist fatalities-aa {
    local lb_var : var label `v'
    local var_nam = subinstr("`lb_var'"," ","_", .)
    rename `v'  total_`var_nam'
}

reshape long total_@, i(county) j(year) string
gen severity = substr(year,6,.)
replace year =  substr(year,1,4)

*spread severity total_
reshape wide total_, i(county year) j(severity) string

ren total_Fatalities total_fatalities
ren total_Injuries total_injuries
destring year, replace

tempfile total_people
save `total_people', replace

/*----------------------------------------------------*/
      /* [>   3.  Animal crash   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/NH/NH.Total&Animal.2002-2013.CountySeverity.Harmon.xlsx"
import excel using "`file_name'" , describe
import excel using "`file_name'", allstring sheet(`r(worksheet_3)') cellrange(`r(range_`s')') firstrow case(lower) clear

foreach v of varlist fatal-an {
    local lb_var : var label `v'
    local var_nam = subinstr("`lb_var'"," ","_", .)
    rename `v'  animal_`var_nam'
}

reshape long animal_@, i(county) j(year) string
gen severity = substr(year,6,.)
replace year =  substr(year,1,4)

*spread severity animal_
reshape wide animal_, i(county year) j(severity) string

ren animal_Fatal animal_fatal
ren animal_Injury animal_injury
ren animal_PDO animal_pdo
destring year, replace

tempfile animal_crash
save `animal_crash', replace

/*----------------------------------------------------*/
      /* [>   4.  Animal people   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/NH/NH.Total&Animal.2002-2013.CountySeverity.Harmon.xlsx"
import excel using "`file_name'" , describe
import excel using "`file_name'", allstring sheet(`r(worksheet_4)') cellrange(`r(range_`s')') firstrow case(lower) clear

foreach v of varlist fatalities-aa {
    local lb_var : var label `v'
    local var_nam = subinstr("`lb_var'"," ","_", .)
    rename `v'  animal_`var_nam'
}

reshape long animal_@, i(county) j(year) string
gen severity = substr(year,6,.)
replace year =  substr(year,1,4)

* spread severity animal_
reshape wide animal_, i(county year) j(severity) string

ren animal_Fatalities animal_fatalities
ren animal_Injuries animal_injuries
destring year, replace

tempfile animal_people
save `animal_people', replace

merge 1:1 county year using `animal_crash', nogen
merge 1:1 county year using `total_people', nogen
merge 1:1 county year using `total_crash', nogenerate

rename county county_name
replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1

tempfile total
save `total', replace

/*----------------------------------------------------*/
      /* [>   5.  Deer fatal 01-14  <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/NH/NH.FatalAnimalCrash.2001-2014.Species.Wilder.xlsx"
import excel using "`file_name'", allstring cellrange(A4:F37) firstrow case(lower) clear

replace year=year[_n-1] if year==""
replace year = strtrim(year)
missings dropobs, force

keep if fatalities =="1"
drop date town

bys county year : gen wild_animal_fatalities =_N
egen deer_fatalities = total(animaltype=="Deer"), by(county year)
drop animaltype fatalities

duplicates drop

set obs 15
replace county = "cheshire" in 15
replace year = "2001" in 15
set obs 16
replace county = "strafford" in 16
replace year = "2001" in 16

destring year, replace
rename county county_name
replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1

merge 1:1 county year using `total', nogen

destring wild_animal_fatalities ///
        deer_fatalities ///
        animal_fatalities ///
        animal_injuries ///
        animal_fatal ///
        animal_injury ///
        animal_pdo ///
        total_fatalities ///
        total_injuries ///
        total_fatal ///
        total_injury ///
        total_pdo ///
        year, ignore("," "NA" " ") replace

assert wild_animal_fatalities>=0 ///
        & deer_fatalities>=0 ///
        & animal_fatalities>=0 ///
        & animal_injuries>=0 ///
        & animal_fatal>=0 ///
        & animal_injury>=0 ///
        & animal_pdo>=0 ///
        & total_fatalities>=0 ///
        & total_injuries>=0 ///
        & total_fatal>=0 ///
        & total_injury>=0 ///
        & total_pdo>=0 , fast // sanity check

/*----------------------------------------------------*/
      /* [>   6. Merge with  state_county_identifiers <] */
/*----------------------------------------------------*/
* creating a balanced dataset
fillin year county_name
drop _fillin

gen state_letter_code  = "NH" // add state abbreviation

local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)
br if _merge!=3
drop _merge

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
	
qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
compress
save "$working_data/dvcs_NH_county_year_`T1'_`T2'.dta" ,replace
