/*******************************************************************************
Program: data_dvcs_county_year.do
Current Lead:  Siyue Ouyang
Major Versions/Revisions:
07/01/2020 [Siyue Ouyang]: created
07/08/2020 [Siyue Ouyang]: code style change
07/13/2020 [Siyue Ouyang]: add more states
07/15/2020 [Siyue Ouyang]: make every single state data ready-to-use, add more states
06/23/2021 [Rukhshan Arif Mian]: commenting out line 68. adding line 69 to rename countycrashreport to county
09/02/2022 [Kaveri Chhikara]: Incorporate new data received in June 2022
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

confirmdir "D:/Dropbox/Research/"
if r(confirmdir) == "0" {
  local rootDir = "D:/Dropbox/Research/"
}

/*
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
*/

global path "`rootDir'/WolvesImpacts/"

global working_data "$path/dataSTATA/intermediate/collisions/"

/*-----------------End of SECTION 0: root directory --------------*/

/*-------------------------
  To Do:
     - [1] derive dta files for all the states
     - [2] merge dta files
-------------------------*/
/*
/*----------------------------------------------------*/
      /* [>   1.  derive dta for 49 states in the folder (~/dataCSV/DVCs/) <] */
/*----------------------------------------------------*/

*************************MN
// clear
// local file_name = "$path/dataCSV/DVCs/MN/MN.TVC.04-18.CountySeverity.xlsx"
// import excel using "`file_name'" , describe
// local Nminus = `r(N_worksheet)' - 1
//
//
// forvalue s = 1/`r(N_worksheet)' {
//     import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(`r(range_`s')') firstrow case(lower) clear
//
//     gen year = `r(worksheet_`s')'
//
//     if year == 2010 | year == 2011 {
//         rename crashesfatal fatalcrashes
//         rename crashesinjury injurycrashes
//         rename crashespropertydamage propertydamagecrashes
//         rename crashestotal totalcrashes
//     }
//
//     if year > = 2012 {
//         rename pdocrashes propertydamagecrashes
//     }
//
//     tempfile newstata`s'
//	
//     save `newstata`s'', replace
// }
//
// forvalue s = 1/`Nminus' {
//     append using `newstata`s'', force
// }
//
// drop h i j
//
// rename countycrashreport county_name
// rename totalcrashes total_total
// rename fatalcrashes total_fatal
// rename injurycrashes total_injury
// rename numberkilled total_fatalities
// rename numberinjured total_injuries
// rename propertydamagecrashes total_pdo
//
// destring total_total ///
//         total_fatal ///
//         total_injury ///
//         total_fatalities ///
//         total_injuries ///
//         total_pdo ///
//         year, ignore("," "NA" " ") replace
//
// assert total_total>=0 ///
//     & total_fatal>=0 ///
//     & total_injury>=0 ///
//     & total_fatalities>=0 ///
//     & total_injuries>=0 ///
//     & total_pdo>=0 , fast // sanity check
//
// replace county_name = lower(county_name)
// replace county_name = strtrim(county_name)
// replace county_name = ustrtrim(county_name)
// drop if county_name == ""
// drop if county_name == "minnesota total"
// drop if county_name == "minnesota totals"
//
//
// * creating a balanced dataset
// fillin year county_name
// drop _fillin
*/
/*----------------------------------------------------*/
      /* [> New Data File- MN-Animal-Crashes_2004-2021 <] */
/*----------------------------------------------------*/

/*----------------------------------------------------*/
      /* [>  Animal Crashes 2004-21   <] */
/*----------------------------------------------------*/

clear
local file_name = "$path/dataRAW/DVCs/MN/MN-Animal-Crashes_2004-2021.xlsx"

import excel using "`file_name'" , describe
import excel using "`file_name'", allstring sheet("AnimalCrashes") cellrange(A4:DW92) case(lower) clear

foreach var of varlist B-DW {
	local name = subinstr(`var'[1], " ", "_", .)
	local year = `var'[2]
	rename `var' N`name'_`year'
}

ren A county_name
drop in 1/2

gen id = _n
reshape long N@, i(id) j(type) string
drop id
split type, parse(_) destring
gen severity = type1 + "_" + type2

drop type1 type2 type
rename type3 year

reshape wide N, i(county_name year) j(severity) string

rename NFatal_Crashes animal_fatal
rename NFatalities_Deaths animal_fatalities
rename NOther_Injuries animal_minor_injuries
rename NOther_Injury animal_minor_injury
rename NPDO_Crashes animal_pdo
rename NSerious_Injuries animal_major_injuries
rename NSerious_Injury animal_major_injury

destring animal*, replace

gen animal_injury = animal_minor_injury + animal_major_injury
gen animal_injuries = animal_minor_injuries + animal_major_injuries
gen animal_total = animal_fatal + animal_injury + animal_pdo
gen imputation_flag_animal_total = 1

tempfile AVCs
save `AVCs', replace

/*----------------------------------------------------*/
      /* [>  Total Crashes 2004-21   <] */
/*----------------------------------------------------*/

clear
local file_name = "$path/dataRAW/DVCs/MN/MN-Animal-Crashes_2004-2021.xlsx"

import excel using "`file_name'" , describe
import excel using "`file_name'", allstring sheet("TotalCrashes") cellrange(A4:DW92) case(lower) clear

foreach var of varlist B-DW {
	local name = subinstr(`var'[1], " ", "_", .)
	local year = `var'[2]
	rename `var' N`name'_`year'
}

ren A county_name
drop in 1/2

gen id = _n
reshape long N@, i(id) j(type) string
drop id
split type, parse(_) destring
gen severity = type1 + "_" + type2

drop type1 type2 type
rename type3 year

reshape wide N, i(county_name year) j(severity) string

rename NFatal_Crashes total_fatal
rename NFatalities_Deaths total_fatalities
rename NOther_Injuries total_minor_injuries
rename NOther_Injury total_minor_injury
rename NPDO_Crashes total_pdo
rename NSerious_Injuries total_major_injuries
rename NSerious_Injury total_major_injury

destring total*, replace

gen total_injury = total_minor_injury + total_major_injury
gen total_injuries = total_minor_injuries +total_major_injuries
gen total_total = total_fatal + total_injury + total_pdo
gen imputation_flag_total_total = 1

/*----------------------------------------------------*/
      /* [>    Merge Animal Crashes and Total Crashes   <] */
/*----------------------------------------------------*/

merge 1:1 county_name year using `AVCs', update
br if _merge != 3
drop _merge

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "total:"
replace county_name = subinstr(county_name, " county", "", .)

assert total_fatal>=0 ///
    & total_injury>=0 ///
    & total_pdo>=0 ///
    & total_fatalities>=0 ///
    & total_injuries>=0 ///
    & total_total>=0 ///
    & animal_fatal>=0 ///
    & animal_injury>=0 ///
    & animal_pdo>=0 ///
    & animal_fatalities>=0 ///
    & animal_injuries>=0 , fast // sanity check

/*----------------------------------------------------*/
      /* [> Merge with state_county_identifiers   <] */
/*----------------------------------------------------*/
gen state_letter_code  = "MN" // add state abbreviation
local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)
br if _merge==1
drop _merge

sort county_name year, stable
order state_letter_code ///
    state_name ///
    county_name ///
    state_fips ///
    county_fips ///
    fips year

drop if year == 2021	
	
qui summ year
local T1 = `r(min)'
local T2 = `r(max)'

compress
save "$working_data/dvcs_MN_county_year_`T1'_`T2'.dta" ,replace


