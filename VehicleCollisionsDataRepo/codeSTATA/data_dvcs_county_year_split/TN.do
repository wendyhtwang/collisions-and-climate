/*******************************************************************************
Program: data_dvcs_county_year.do
Current Lead:  Siyue Ouyang
Major Versions/Revisions:
07/01/2020 [Siyue Ouyang]: created
07/08/2020 [Siyue Ouyang]: code style change
07/13/2020 [Siyue Ouyang]: add more states
07/15/2020 [Siyue Ouyang]: make every single state data ready-to-use, add more states
09/03/2021 [Kaveri Chhikara]: updated code to include possible injury, total injury, unknown severity, animal collisions and deer collisions.
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

*************************TN (all data were kept)
/*----------------------------------------------------*/
      /* [>   1.  Total 16-19   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataCSV/DVCs/TN/TN.TVC.16-19.CountySeverity.xlsx"
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

rename tennesseetrafficcrashesbyyea county_name
rename fatal total_fatal
rename injury total_injury
rename pdo total_pdo
rename total total_total

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if strpos(county_name,"total") == 1
replace county_name = subinstr(county_name, " county", "", .)
replace county_name = "van buren" if county_name == "vanburen"

drop if county_name==""

local pct "  · ~ ～ ! ！ @ @ # # $ ￥ % % ^ ……  & & * × ( ) （ ） - - _  ——  =  = +  +  [ ] 『 』 { } 【 】  |  \   、 ; ； : ： , ， < > 《 》 . 。 / ? ？ ‘  ’  “  ” "
foreach x of local pct {
      replace county_name = subinstr(county_name, "`x'", "", .)
 }

sort county_name year, stable
destring total*, replace 

tempfile CSV
save `CSV', replace
  
/*----------------------------------------------------*/
      /* [>   2.  Total 10-19   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/TN/vwLookup_County.txt"
import delimited using "`file_name'", clear delimiter("|") varnames(1) case(lower) stringcols(_all)
keep countystatecde countynametxt countyfipscde

tempfile county_code
save `county_code', replace
 
clear
local file_name = "$path/dataRAW/DVCs/TN/vwCollision.txt"
import delimited using "`file_name'", clear delimiter("|") varnames(1) case(lower) stringcols(_all) bindquote(strict) maxquotedrows(99999999)
  
keep mstrrecnbrtxt collisiondte nbrfatalitiesnmb nbrinjurednmb countystatecde crashtypecde firstharmfuleventcde
 
gen year = substr(collisiondte,1,4)
destring year nbrfatalitiesnmb nbrinjurednmb, replace
tempfile f
save `f', replace
 

bys county year: egen total_fatalities=total(nbrfatalitiesnmb) // total_fatalities
bys county year: egen total_injuries =total(nbrinjurednmb) // total_injuries
bys county year: gen total_total =_N // total_total

egen total_fatal = total(crashtypecde == "01"), by(county year)
egen total_major_injury = total(crashtypecde == "02"), by(county year)
egen total_minor_injury = total(crashtypecde == "03"), by(county year)
egen total_possible_injury = total(crashtypecde == "04"), by(county year)
gen total_injury = total_major_injury + total_minor_injury + total_possible_injury
egen total_pdo = total(crashtypecde == "05"), by(county year)
egen total_unknown_severity = total(crashtypecde == "99"), by(county year)

tempfile total
save `total', replace


* add animal collisions
clear
use `f', replace 

gen is_animal = 1 if firstharmfuleventcde == "11" | firstharmfuleventcde == "58"
keep if is_animal == 1

bys county year: egen animal_fatalities = total(nbrfatalitiesnmb)
bys county year: egen animal_injuries = total(nbrinjurednmb) 
bys county year: gen animal_total = _N


egen animal_fatal = total(crashtypecde == "01" ) , by(county year)
egen animal_major_injury = total(crashtypecde == "02"), by(county year)
egen animal_minor_injury = total(crashtypecde == "03"), by(county year)
egen animal_possible_injury = total(crashtypecde == "04"), by(county year)
gen animal_injury = animal_major_injury + animal_minor_injury + animal_possible_injury
egen animal_pdo = total(crashtypecde == "05"), by(county year)
egen animal_unknown_severity = total(crashtypecde == "99"), by(county year)

tempfile animal
save `animal', replace


* add deer collisions 
clear
use `f', replace 

gen is_deer = 1 if firstharmfuleventcde == "58"
keep if is_deer == 1

bys county year: egen deer_fatalities = total(nbrfatalitiesnmb)
bys county year: egen deer_injuries = total(nbrinjurednmb) 
bys county year: gen deer_total = _N

egen deer_fatal = total(crashtypecde == "01") , by(county year)
egen deer_major_injury = total(crashtypecde == "02"), by(county year)
egen deer_minor_injury = total(crashtypecde == "03" ), by(county year)
egen deer_possible_injury = total(crashtypecde == "04"), by(county year)
gen deer_injury = deer_major_injury + deer_minor_injury + deer_possible_injury
egen deer_pdo = total(crashtypecde == "05"), by(county year)
egen deer_unknown_severity = total(crashtypecde == "99"), by(county year)

tempfile deer
save `deer', replace

merge 1:1 mstrrecnbrtxt year using `total' , nogenerate
merge 1:1 mstrrecnbrtxt year using `animal', nogenerate 
merge m:1 countystatecde using `county_code', nogenerate

drop mstrrecnbrtxt collisiondte nbrfatalitiesnmb nbrinjurednmb crashtypecde firstharmfuleventcde is_deer is_animal countystatecde countyfipscde

ren countynametxt county_name

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "total:"
replace county_name = subinstr(county_name, " county", "", .)
replace county_name = "van buren" if county_name == "vanburen"

drop if county_name==""
drop if animal_total == .
drop if deer_total == . 

order county_name year total* animal* deer*
sort county_name year, stable
duplicates drop
 
/*----------------------------------------------------*/
      /* [>   3.  Merge with CSV   <] */
/*----------------------------------------------------*/
merge 1:1 county_name year using `CSV', force
br if _merge != 3
drop _merge

assert total_fatal>=0 ///
    & total_injury>=0 ///
    & total_fatalities>=0 ///
    & total_injuries>=0 ///
    & total_pdo>=0 ///
    & total_total>=0 ///
	& animal_fatal>=0 ///
    & animal_injury>=0 ///
    & animal_fatalities>=0 ///
    & animal_injuries>=0 ///
    & animal_pdo>=0 ///
    & animal_total>=0 ///
	& deer_fatal>=0 ///
    & deer_injury>=0 ///
    & deer_fatalities>=0 ///
    & deer_injuries>=0 ///
    & deer_pdo>=0 ///
    & deer_total>=0, fast // sanity check



/*----------------------------------------------------*/
      /* [>   4.  Merge with state_county_identifiers   <] */
/*----------------------------------------------------*/
* creating a balanced dataset
fillin year county_name
drop _fillin

gen state_letter_code  = "TN" // add state abbreviation


local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)
br if _merge==1
drop _merge

drop if year == 2020
drop if county_name == "total" | county_name == "unknown"

order state_letter_code ///
    state_name ///
    county_name ///
    state_fips ///
    county_fips ///
    fips year
	
sort county_name year, stable 
qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
compress
save "$working_data/dvcs_TN_county_year_`T1'_`T2'.dta" ,replace
