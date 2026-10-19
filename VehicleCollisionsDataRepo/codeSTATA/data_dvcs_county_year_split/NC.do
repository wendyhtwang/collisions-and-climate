/*******************************************************************************
Program: data_dvcs_county_year.do
Current Lead:  Kaveri Chhikara
Major Versions/Revisions:
09/17/2021 [Kaveri Chhikara]: created
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

confirmdir "/mnt/data_d/Dropbox/Research"
if r(confirmdir) == "0" {
  local rootDir = "/mnt/data_d/Dropbox/Research"
}
confirmdir "C:/Dropbox"
if r(confirmdir) == "0" {
  local rootDir = "C:/Dropbox/Research"
}
confirmdir "D:/Dropbox"
if r(confirmdir) == "0" {
  local rootDir = "D:/Dropbox/Research"
}

global path "`rootDir'/VehicleCollisionsDataRepo"
global working_data "$path/dataSTATA"

/*----------------------------------------------------*/
      /* [>   1.  TVCs and AVCs from 1990-19 */
/*----------------------------------------------------*/

clear
cd "$path/dataRAW/DVCs/NC/"
set excelxlsxlargefile on
local all_files : dir . files "*.xlsx"
display `all_files'

tempfile allcrashes
set obs 1
gen drop_me = 1
save `allcrashes', replace

foreach file in `all_files' {
	clear
	import excel using "`file'", firstrow clear

	keep COUNTY CRASH_DATE First_Harmful_Event SEVERITY TotalFatalities TotalInjuries 
	
	append using `allcrashes'
	save `allcrashes', replace
}

stop
drop if drop_me == 1
drop drop_me

format %tdDD/NN/CCYY CRASH_DATE
gen year = year(CRASH_DATE)
drop CRASH_DATE

rename COUNTY county_name
rename First_Harmful_Event crash_type
rename SEVERITY crash_severity

egen total_fatal = total(crash_severity == "K"), by(county_name year)
egen total_major_injury = total(crash_severity == "A"), by(county_name year)
egen total_minor_injury = total(crash_severity == "B"), by(county_name year)
egen total_possible_injury = total(crash_severity == "C"), by(county_name year)
egen total_pdo = total(crash_severity == "O"), by(county_name year)
egen total_injuries = total(TotalInjuries), by(county_name year)
egen total_fatalities = total(TotalFatalities), by(county_name year)
gen total_injury = total_major_injury +total_minor_injury +total_possible_injury
gen total_total = total_fatal + total_injury + total_pdo
 
drop crash_type crash_severity TotalFatalities TotalInjuries 
duplicates drop

tempfile total
save `total', replace

clear
// import excel using "`file'", firstrow clear
use `allcrashes', clear
keep COUNTY CRASH_DATE First_Harmful_Event SEVERITY TotalFatalities TotalInjuries 
stop
format %tdDD/NN/CCYY CRASH_DATE
gen year = year(CRASH_DATE)
drop CRASH_DATE

rename COUNTY county_name
rename First_Harmful_Event crash_type
rename SEVERITY crash_severity
keep if crash_type == "ANIMAL"

egen animal_fatal = total(crash_severity == "K"), by(county_name year)
egen animal_major_injury = total(crash_severity == "A"), by(county_name year)
egen animal_minor_injury = total(crash_severity == "B"), by(county_name year)
egen animal_possible_injury = total(crash_severity == "C"), by(county_name year)
egen animal_pdo = total(crash_severity == "O"), by(county_name year)
egen animal_injuries = total(TotalInjuries), by(county_name year)
egen animal_fatalities = total(TotalFatalities), by(county_name year)	
gen animal_injury = animal_major_injury + animal_minor_injury + animal_possible_injury
gen animal_total = animal_fatal + animal_injury + animal_pdo 

drop crash_type crash_severity TotalFatalities TotalInjuries 
duplicates drop

tempfile animal
save `animal', replace 

merge 1:1 county_name year  using `total', nogen

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1

//drop if year == 2020

assert total_total >=0  ///
	& total_fatal >=0 ///
	& total_injury >=0 ///
	& total_pdo >=0 ///	
	& total_major_injury >=0 ///
	& total_minor_injury >=0 ///
	& total_possible_injury >=0 ///
	& total_fatalities >= 0 ///
	& total_injuries >= 0 ///	
    & animal_total >=0 ///
	& animal_fatal >=0 ///
    & animal_injury >=0 ///
	& animal_pdo >= 0 ///
	& animal_major_injury >=0 ///
	& animal_minor_injury >=0 ///
	& animal_possible_injury >=0 ///	
	& animal_fatalities >= 0 ///
	& total_injuries >= 0, fast // sanity check

/*----------------------------------------------------*/
      /* [>   4.  Merge with state_county_identifiers  <] */
/*----------------------------------------------------*/

gen state_letter_code  = "NC"
local state_county_identifiers "$path/dataSTATA/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3) 
br if _merge==1
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
save "$working_data/dvcs_NC_county_year_`T1'_`T2'.dta" ,replace


